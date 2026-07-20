import { BadRequestException } from "@nestjs/common";
import { z } from "zod";

/** Shared zod → 400 with the standard error envelope. */
export function parse<S extends z.ZodTypeAny>(schema: S, body: unknown): z.output<S> {
  const result = schema.safeParse(body);
  if (!result.success) {
    throw new BadRequestException({
      error: "validation_error",
      message: "Invalid request body",
      details: result.error.flatten().fieldErrors
    });
  }
  return result.data;
}
