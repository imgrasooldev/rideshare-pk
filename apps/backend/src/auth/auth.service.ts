import { Inject, Injectable, UnauthorizedException } from "@nestjs/common";
import type { AppConfig } from "../config/config.js";
import type { KeyValueStore } from "../shared/kv.js";
import { APP_CONFIG, KV_STORE, USER_REPOSITORY } from "../shared/tokens.js";
import type { UserRecord, UserRepository } from "../users/users.repo.js";
import { OtpService } from "./otp.service.js";
import { TokenService } from "./token.service.js";

export interface AuthResult {
  accessToken: string;
  refreshToken: string;
  user: UserRecord;
}

@Injectable()
export class AuthService {
  constructor(
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(KV_STORE) private readonly kv: KeyValueStore,
    @Inject(USER_REPOSITORY) private readonly users: UserRepository,
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

  private async issueTokens(user: UserRecord): Promise<AuthResult> {
    const accessToken = this.tokens.signAccess({ sub: user.id, phone: user.phone });
    const { token: refreshToken, jti } = this.tokens.signRefresh(user.id);
    await this.kv.set(`refresh:${jti}`, user.id, this.config.JWT_REFRESH_TTL);
    return { accessToken, refreshToken, user };
  }
}
