import type { NextConfig } from "next";

// Static export served by the backend at /admin — one deploy, no extra hosting.
const nextConfig: NextConfig = {
  output: "export",
  basePath: "/admin",
  trailingSlash: true,
  images: { unoptimized: true }
};

export default nextConfig;
