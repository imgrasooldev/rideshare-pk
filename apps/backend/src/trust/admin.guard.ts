import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Inject,
  Injectable,
  UnauthorizedException
} from "@nestjs/common";
import { TokenService } from "../auth/token.service.js";
import type { AuthedRequest } from "../auth/jwt-auth.guard.js";
import { USER_REPOSITORY } from "../shared/tokens.js";
import type { UserRepository } from "../users/users.repo.js";

@Injectable()
export class AdminGuard implements CanActivate {
  constructor(
    private readonly tokens: TokenService,
    @Inject(USER_REPOSITORY) private readonly users: UserRepository
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<AuthedRequest>();
    const header = req.headers.authorization;
    if (!header?.startsWith("Bearer ")) {
      throw new UnauthorizedException("Missing bearer token");
    }
    const claims = this.tokens.verifyAccess(header.slice("Bearer ".length));
    const user = await this.users.findById(claims.sub);
    if (!user?.isAdmin) {
      throw new ForbiddenException("Admin access required");
    }
    req.user = claims;
    return true;
  }
}
