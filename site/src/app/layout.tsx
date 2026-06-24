import type { Metadata, Viewport } from "next";
import { Plus_Jakarta_Sans, Space_Grotesk } from "next/font/google";
import "./globals.css";

const spaceGrotesk = Space_Grotesk({
  subsets: ["latin"],
  weight: ["500", "600", "700"],
  variable: "--font-space-grotesk",
  display: "swap",
});

const plusJakarta = Plus_Jakarta_Sans({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
  variable: "--font-plus-jakarta",
  display: "swap",
});

export const metadata: Metadata = {
  title: "PowerSnek",
  description:
    "A free macOS menu-bar app that celebrates when your charger connects.",
  metadataBase: new URL("https://powersnek.s11a.com"),
  openGraph: {
    title: "PowerSnek",
    description:
      "Plug in. Watch a green comet trace your MacBook notch.",
    url: "https://powersnek.s11a.com",
    siteName: "PowerSnek",
    type: "website",
  },
};

export const viewport: Viewport = {
  themeColor: "#e9ecdb",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`${spaceGrotesk.variable} ${plusJakarta.variable}`}>
      <body>{children}</body>
    </html>
  );
}
