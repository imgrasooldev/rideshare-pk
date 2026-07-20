import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException
} from "@nestjs/common";
import { USER_REPOSITORY, VEHICLE_REPOSITORY, VERIFICATION_REPOSITORY } from "../shared/tokens.js";
import type { UserRepository } from "../users/users.repo.js";
import type { VehicleRepository } from "../vehicles/vehicles.repo.js";
import type {
  PendingPage,
  VerificationRecord,
  VerificationRepository,
  VerificationType
} from "./verifications.repo.js";

@Injectable()
export class TrustService {
  constructor(
    @Inject(VERIFICATION_REPOSITORY) private readonly verifications: VerificationRepository,
    @Inject(USER_REPOSITORY) private readonly users: UserRepository,
    @Inject(VEHICLE_REPOSITORY) private readonly vehicles: VehicleRepository
  ) {}

  async submit(userId: string, type: VerificationType, docUrl: string, vehicleId?: string): Promise<VerificationRecord> {
    if (type === "vehicle") {
      if (!vehicleId) throw new BadRequestException("vehicleId is required for vehicle verification");
      const vehicle = await this.vehicles.findById(vehicleId);
      if (!vehicle || vehicle.ownerId !== userId) {
        throw new ForbiddenException("Vehicle not found or not yours");
      }
    }
    return this.verifications.create(userId, type, docUrl, vehicleId ?? null);
  }

  listPending(cursor: string | null, limit: number): Promise<PendingPage> {
    return this.verifications.listPending(cursor, limit);
  }

  /**
   * Approve/reject. Approval side-effects: cnic → user gains the verified
   * badge; vehicle → that vehicle is marked verified. A verification can be
   * reviewed exactly once (repo updates only pending rows).
   */
  async review(id: string, action: "approve" | "reject", reviewerId: string, notes?: string): Promise<VerificationRecord> {
    const status = action === "approve" ? "approved" : "rejected";
    const reviewed = await this.verifications.review(id, status, reviewerId, notes ?? null);
    if (!reviewed) throw new NotFoundException("Verification not found or already reviewed");

    if (reviewed.status === "approved") {
      if (reviewed.type === "cnic") {
        await this.users.setVerified(reviewed.userId, true);
      } else if (reviewed.type === "vehicle" && reviewed.vehicleId) {
        await this.vehicles.setVerified(reviewed.vehicleId, true);
      }
    }
    return reviewed;
  }
}
