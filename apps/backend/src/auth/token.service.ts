import { randomUUID } from "node:crypto";
import { Inject, Injectable, UnauthorizedException } from "@nestjs/common";
import jwt from "jsonwebtoken";
import type { AppConfig } from "../config/config.js";
import { APP_CONFIG } from "../shared/tokens.js";

export interface AccessClaims {
  sub: string; // user id
  phone: string;
}

export interface RefreshClaims {
  sub: string;
  jti: string;
}

@Injectable()
export class TokenService {
  constructor(@Inject(APP_CONFIG) private readonly config: AppConfig) {}

  signAccess(claims: AccessClaims): string {
    return jwt.sign({ ...claims, typ: "access" }, this.config.JWT_ACCESS_SECRET, {
      expiresIn: this.config.JWT_ACCESS_TTL
    });
  }

  signRefresh(userId: string): { token: string; jti: string } {
    const jti = randomUUID();
    const token = jwt.sign({ sub: userId, jti, typ: "refresh" }, this.config.JWT_REFRESH_SECRET, {
      expiresIn: this.config.JWT_REFRESH_TTL
    });
    return { token, jti };
  }

  verifyAccess(token: string): AccessClaims {
    const payload = this.verify(token, this.config.JWT_ACCESS_SECRET, "access");
    return { sub: String(payload.sub), phone: String(payload.phone) };
  }

  verifyRefresh(token: string): RefreshClaims {
    const payload = this.verify(token, this.config.JWT_REFRESH_SECRET, "refresh");
    return { sub: String(payload.sub), jti: String(payload.jti) };
  }

  private verify(token: string, secret: string, typ: "access" | "refresh"): jwt.JwtPayload {
    try {
      const payload = jwt.verify(token, secret);
      if (typeof payload === "string" || payload.typ !== typ) {
        throw new Error("wrong token type");
      }
      return payload;
    } catch {
      throw new UnauthorizedException("Invalid or expired token");
    }
  }
}
