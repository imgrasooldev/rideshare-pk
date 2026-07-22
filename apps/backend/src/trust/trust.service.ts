import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException
} from "@nestjs/common";
import {
  DOCUMENT_STORAGE,
  USER_REPOSITORY,
  VEHICLE_REPOSITORY,
  VERIFICATION_REPOSITORY
} from "../shared/tokens.js";
import type { DocumentStorage } from "../storage/storage.provider.js";
import type { UserRepository } from "../users/users.repo.js";
import type { VehicleRepository } from "../vehicles/vehicles.repo.js";
import type {
  DocumentRef,
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
    @Inject(VEHICLE_REPOSITORY) private readonly vehicles: VehicleRepository,
    @Inject(DOCUMENT_STORAGE) private readonly storage: DocumentStorage
  ) {}

  async submit(userId: string, type: VerificationType, doc: DocumentRef, vehicleId?: string): Promise<VerificationRecord> {
    if (type === "vehicle") {
      if (!vehicleId) throw new BadRequestException("vehicleId is required for vehicle verification");
      const vehicle = await this.vehicles.findById(vehicleId);
      if (!vehicle || vehicle.ownerId !== userId) {
        throw new ForbiddenException("Vehicle not found or not yours");
      }
    }
    // An uploaded key is namespaced by user id — refuse one that belongs to
    // someone else, so a caller can't attach another user's document.
    if (doc.docKey && !doc.docKey.startsWith(`${userId}/`)) {
      throw new ForbiddenException("That upload does not belong to you");
    }
    return this.verifications.create(userId, type, doc, vehicleId ?? null);
  }

  /**
   * Reviewer-only: turn the stored private key into a short-lived view URL.
   * External legacy links are returned as-is.
   */
  async documentUrl(verificationId: string, ttlSeconds: number): Promise<{ url: string }> {
    const record = await this.verifications.findById(verificationId);
    if (!record) throw new NotFoundException("Verification not found");
    if (record.docKey) {
      return { url: await this.storage.createViewUrl(record.docKey, ttlSeconds) };
    }
    if (record.docUrl) return { url: record.docUrl };
    throw new NotFoundException("This submission has no document attached");
  }

  listPending(cursor: string | null, limit: number): Promise<PendingPage> {
    return this.verifications.listPending(cursor, limit);
  }

  listMine(userId: string): Promise<VerificationRecord[]> {
    return this.verifications.listByUser(userId, 20);
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
