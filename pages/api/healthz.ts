import type { NextApiRequest, NextApiResponse } from "next";

/**
 * Liveness probe for load balancers and orchestrators (GET only).
 */
export default function handler(
  request: NextApiRequest,
  response: NextApiResponse<{ status: string }>
) {
  if (request.method !== "GET") {
    response.setHeader("Allow", "GET");
    return response.status(405).json({ status: "method_not_allowed" });
  }

  response.setHeader("Cache-Control", "no-store");
  return response.status(200).json({ status: "ok" });
}
