import { BadRequestException, Inject, Injectable, NotFoundException } from "@nestjs/common";
import { normalizePkPhone } from "../auth/phone.js";
import type { AppConfig } from "../config/config.js";
import { decryptString, encryptString } from "../shared/crypto.js";
import { PlacesRepository } from "../places/places.repo.js";
import { APP_CONFIG, USER_REPOSITORY } from "../shared/tokens.js";
import type { UserRecord, UserRepository } from "./users.repo.js";

export interface ProfileView {
  id: string;
  phone: string | null;
  email: string | null;
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
  isOnline: boolean;
}

export interface UpdateMeInput {
  name?: string;
  role?: UserRecord["role"];
  gender?: NonNullable<UserRecord["gender"]>;
  cnic?: string;
  emergencyPhone?: string;
  city?: string;
}

@Injectable()
export class UsersService {
  constructor(
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(USER_REPOSITORY) private readonly users: UserRepository,
    private readonly places: PlacesRepository
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
    let city: string | undefined;
    if (input.city !== undefined) {
      // Validate against the real city list: an unknown slug would silently
      // leave the user in a city with no hubs and no rides.
      const slug = input.city.trim().toLowerCase();
      const known = await this.places.cities();
      if (!known.some((c) => c.slug === slug)) {
        throw new BadRequestException(
          `Unknown city. Available: ${known.map((c) => c.slug).join(", ")}`
        );
      }
      city = slug;
    }
    const updated = await this.users.updateProfile(userId, {
      name: input.name,
      role: input.role,
      gender: input.gender,
      cnic: cnicEncrypted,
      emergencyPhone,
      city
    });
    if (!updated) throw new NotFoundException("User not found");
    return this.toView(updated);
  }

  async setOnline(userId: string, online: boolean): Promise<ProfileView> {
    const updated = await this.users.setOnline(userId, online);
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
      email: user.email,
      name: user.name,
      role: user.role,
      gender: user.gender,
      cnicMasked,
      verified: user.verified,
      city: user.city,
      ratingAvg: user.ratingAvg,
      ratingCount: user.ratingCount,
      emergencyPhone: user.emergencyPhone,
      isOnline: user.isOnline
    };
  }
}
