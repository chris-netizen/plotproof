import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "PlotProof — every land claim on Monad, on one map",
  description:
    "PlotProof is a public, on-chain registry of land claims. Check any plot before you pay — see who claimed it, when, and whether there are competing claims.",
  openGraph: {
    title: "PlotProof — check before you pay",
    description:
      "A public, tamper-proof map of land claims on Monad. Verify any plot before you buy.",
    type: "website",
  },
  icons: {
    icon: "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E%3Crect width='32' height='32' rx='8' fill='%230f7a3d'/%3E%3Cpath d='M16 7a6 6 0 0 0-6 6c0 4.2 6 12 6 12s6-7.8 6-12a6 6 0 0 0-6-6zm0 8.2A2.2 2.2 0 1 1 16 10.8a2.2 2.2 0 0 1 0 4.4z' fill='white'/%3E%3C/svg%3E",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
