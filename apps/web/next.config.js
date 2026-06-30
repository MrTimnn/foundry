const { withContentlayer } = require("next-contentlayer");
const nextConfig = {
  reactStrictMode: true,
  transpilePackages: ["@foundry/ui"],
  output: "standalone",
};
module.exports = withContentlayer(nextConfig);
