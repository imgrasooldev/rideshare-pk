import { randomBytes } from "node:crypto";
import {
  BadRequestException,
  ConflictException,
  HttpException,
  HttpStatus,
  Inject,
  Injectable,
  UnauthorizedException
} from "@nestjs/common";
import bcrypt from "bcryptjs";
import type { AppConfig } from "../config/config.js";
import type { KeyValueStore } from "../shared/kv.js";
import {
  APP_CONFIG,
  IDENTITY_REPOSITORY,
  KV_STORE,
  OAUTH_VERIFIER,
  USER_REPOSITORY
} from "../shared/tokens.js";
import type { UserRecord, UserRepository } from "../users/users.repo.js";
import type { IdentityRepository, SocialProvider } from "./identities.repo.js";
import type { OAuthVerifier, SocialProfile } from "./oauth.verifier.js";
import { OtpService } from "./otp.service.js";
import { TokenService } from "./token.service.js";

export interface AuthResult {
  accessToken: string;
  refreshToken: string;
  user: UserRecord;
}

const RESET_TOKEN_TTL_S = 1800; // 30 min
const LOGIN_ATTEMPT_LIMIT = 5; // per email per 15 min

@Injectable()
export class AuthService {
  constructor(
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(KV_STORE) private readonly kv: KeyValueStore,
    @Inject(USER_REPOSITORY) private readonly users: UserRepository,
    @Inject(IDENTITY_REPOSITORY) private readonly identities: IdentityRepository,
    @Inject(OAUTH_VERIFIER) private readonly oauth: OAuthVerifier,
    private readonly otp: OtpService,
    private readonly tokens: TokenService
  ) {}

  async loginWithOtp(rawPhone: string, code: string): Promise<AuthResult> {
    const phone = await this.otp.verifyOtp(rawPhone, code);
    const user = await this.users.upsertByPhone(phone, this.config.CITY_DEFAULT);
    return this.issueTokens(user);
  }

  /**
   * Refresh with rotation: each refresh token is single-use (its jti is
   * deleted when spent), so a stolen-and-replayed token is rejected.
   */
  async refresh(refreshToken: string): Promise<AuthResult> {
    const claims = this.tokens.verifyRefresh(refreshToken);
    const key = `refresh:${claims.jti}`;
    const userId = await this.kv.get(key);
    if (!userId || userId !== claims.sub) {
      throw new UnauthorizedException("Refresh token revoked or already used");
    }
    await this.kv.del(key);

    const user = await this.users.findById(claims.sub);
    if (!user) {
      throw new UnauthorizedException("User no longer exists");
    }
    return this.issueTokens(user);
  }

  // ---------- Email / password ----------

  async register(email: string, password: string, name: string | null): Promise<AuthResult> {
    const existing = await this.users.findByEmail(email);
    if (existing) {
      throw new ConflictException("An account with this email already exists — log in instead");
    }
    const user = await this.users.createWithEmail({
      email,
      passwordHash: await bcrypt.hash(password, 10),
      name,
      emailVerified: false,
      city: this.config.CITY_DEFAULT
    });
    return this.issueTokens(user);
  }

  async loginWithPassword(email: string, password: string): Promise<AuthResult> {
    const attempts = await this.kv.incr(`login:rl:${email.toLowerCase()}`, 900);
    if (attempts > LOGIN_ATTEMPT_LIMIT) {
      throw new HttpException(
        "Too many attempts. Try again in 15 minutes or reset your password.",
        HttpStatus.TOO_MANY_REQUESTS
      );
    }
    const user = await this.users.findByEmail(email);
    // One generic error for every failure mode — no account enumeration.
    if (!user?.passwordHash || !(await bcrypt.compare(password, user.passwordHash))) {
      throw new UnauthorizedException("Incorrect email or password");
    }
    await this.kv.del(`login:rl:${email.toLowerCase()}`);
    return this.issueTokens(user);
  }

  /** Always resolves with the same message — no account enumeration. */
  async forgotPassword(email: string): Promise<{ devResetToken?: string }> {
    const user = await this.users.findByEmail(email);
    if (!user) return {};
    const token = randomBytes(24).toString("hex");
    await this.kv.set(`pwdreset:${token}`, user.id, RESET_TOKEN_TTL_S);
    // Email delivery lands with the notifications module; dev mode surfaces
    // the token so the flow is fully usable today.
    return this.config.OTP_DEV_MODE ? { devResetToken: token } : {};
  }

  async resetPassword(token: string, newPassword: string): Promise<void> {
    const userId = await this.kv.get(`pwdreset:${token}`);
    if (!userId) {
      throw new BadRequestException("Reset link is invalid or expired — request a new one");
    }
    await this.users.setPassword(userId, await bcrypt.hash(newPassword, 10));
    await this.kv.del(`pwdreset:${token}`);
  }

  // ---------- Social sign-in ----------

  async loginWithGoogle(idToken: string): Promise<AuthResult> {
    return this.socialLogin("google", await this.oauth.verifyGoogle(idToken));
  }

  async loginWithFacebook(accessToken: string): Promise<AuthResult> {
    return this.socialLogin("facebook", await this.oauth.verifyFacebook(accessToken));
  }

  private async socialLogin(provider: SocialProvider, profile: SocialProfile): Promise<AuthResult> {
    const identity = await this.identities.find(provider, profile.uid);
    if (identity) {
      const user = await this.users.findById(identity.userId);
      if (!user) throw new UnauthorizedException("Account no longer exists");
      return this.issueTokens(user);
    }

    // First social login: link to an existing account with the same verified
    // email, otherwise create a fresh one.
    let user = profile.email && profile.emailVerified
      ? await this.users.findByEmail(profile.email)
      : null;
    user ??= await this.users.createWithEmail({
      email: profile.email,
      passwordHash: null,
      name: profile.name,
      emailVerified: profile.emailVerified,
      city: this.config.CITY_DEFAULT
    });
    await this.identities.link(user.id, provider, profile.uid, profile.email);
    return this.issueTokens(user);
  }

  private async issueTokens(user: UserRecord): Promise<AuthResult> {
    const accessToken = this.tokens.signAccess({ sub: user.id, phone: user.phone });
    const { token: refreshToken, jti } = this.tokens.signRefresh(user.id);
    await this.kv.set(`refresh:${jti}`, user.id, this.config.JWT_REFRESH_TTL);
    return { accessToken, refreshToken, user };
  }
}
