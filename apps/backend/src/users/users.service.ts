import { BadRequestException, Inject, Injectable, NotFoundException } from "@nestjs/common";
import { normalizePkPhone } from "../auth/phone.js";
import type { AppConfig } from "../config/config.js";
import { decryptString, encryptString } from "../shared/crypto.js";
import { APP_CONFIG, USER_REPOSITORY } from "../shared/tokens.js";
import type { UserRecord, UserRepository } from "./users.repo.js";

export interface ProfileView {
  id: string;
  phone: string;
  name: string | null;
  role: UserRecord["role"];
  gender: UserRecord["gender"];
  /** Masked — full CNIC is never returned by the API. */
  cnicMasked: string | null;
  verified: boolean;
  city: string;
  ratingAvg: number;
  ratingCount: number;
  emergencyPhone: string | null;
}

export interface UpdateMeInput {
  name?: string;
  role?: UserRecord["role"];
  gender?: NonNullable<UserRecord["gender"]>;
  cnic?: string;
  emergencyPhone?: string;
}

@Injectable()
export class UsersService {
  constructor(
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(USER_REPOSITORY) private readonly users: UserRepository
  ) {}

  async getMe(userId: string): Promise<ProfileView> {
    const user = await this.users.findById(userId);
    if (!user) throw new NotFoundException("User not found");
    return this.toView(user);
  }

  async updateMe(userId: string, input: UpdateMeInput): Promise<ProfileView> {
    let cnicEncrypted: string | undefined;
    if (input.cnic !== undefined) {
      const digits = input.cnic.replace(/-/g, "");
      if (!/^\d{13}$/.test(digits)) {
        throw new BadRequestException("CNIC must be 13 digits (e.g. 35202-1234567-1)");
      }
      cnicEncrypted = encryptString(digits, this.config.CNIC_ENC_KEY);
    }
    let emergencyPhone: string | undefined;
    if (input.emergencyPhone !== undefined) {
      const normalised = normalizePkPhone(input.emergencyPhone);
      if (!normalised) {
        throw new BadRequestException("Emergency contact must be a Pakistani mobile number");
      }
      emergencyPhone = normalised;
    }
    const updated = await this.users.updateProfile(userId, {
      name: input.name,
      role: input.role,
      gender: input.gender,
      cnic: cnicEncrypted,
      emergencyPhone
    });
    if (!updated) throw new NotFoundException("User not found");
    return this.toView(updated);
  }

  private toView(user: UserRecord): ProfileView {
    let cnicMasked: string | null = null;
    if (user.cnic) {
      try {
        const digits = decryptString(user.cnic, this.config.CNIC_ENC_KEY);
        cnicMasked = `*********${digits.slice(-4)}`;
      } catch {
        cnicMasked = null; // key rotated without migration — treat as unset
      }
    }
    return {
      id: user.id,
      phone: user.phone,
      name: user.name,
      role: user.role,
      gender: user.gender,
      cnicMasked,
      verified: user.verified,
      city: user.city,
      ratingAvg: user.ratingAvg,
      ratingCount: user.ratingCount,
      emergencyPhone: user.emergencyPhone
    };
  }
}
