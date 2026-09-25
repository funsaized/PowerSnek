/// <reference types="vite/client" />
import {
  HeadContent,
  Scripts,
  createRootRoute,
} from "@tanstack/react-router";
import type { ReactNode } from "react";
import { DMG_URL, LATEST_VERSION, REPO_URL } from "../release";
import appCss from "../styles.css?url";

const siteUrl = "https://powersnek.s11a.com/";
const title = "PowerSnek: a charging animation for your Mac's notch";
const description =
  "PowerSnek is a free, open-source macOS menu bar app that traces your screen and MacBook notch with a glowing comet the moment your charger connects.";
const socialDescription = "Plug in. Watch a glowing comet trace your MacBook's screen and notch.";
const ogImage = `${siteUrl}og.png`;
const ogImageAlt =
  "PowerSnek: a green comet tracing a MacBook screen and notch, with a 47% · Charging readout.";

const softwareApplication = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: "PowerSnek",
  description,
  url: siteUrl,
  image: ogImage,
  applicationCategory: "UtilitiesApplication",
  operatingSystem: "macOS 14 or later",
  softwareVersion: LATEST_VERSION,
  downloadUrl: DMG_URL,
  license: "https://www.apache.org/licenses/LICENSE-2.0",
  isAccessibleForFree: true,
  offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
  sameAs: [REPO_URL],
};

export const Route = createRootRoute({
  head: () => ({
    meta: [
      { charSet: "utf-8" },
      { name: "viewport", content: "width=device-width, initial-scale=1" },
      { title },
      { name: "description", content: description },
      { name: "robots", content: "index, follow, max-image-preview:large" },
      { name: "theme-color", content: "#e9ecdb" },
      { name: "application-name", content: "PowerSnek" },
      { property: "og:type", content: "website" },
      { property: "og:site_name", content: "PowerSnek" },
      { property: "og:locale", content: "en_US" },
      { property: "og:url", content: siteUrl },
      { property: "og:title", content: title },
      { property: "og:description", content: socialDescription },
      { property: "og:image", content: ogImage },
      { property: "og:image:type", content: "image/png" },
      { property: "og:image:width", content: "1200" },
      { property: "og:image:height", content: "630" },
      { property: "og:image:alt", content: ogImageAlt },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "twitter:title", content: title },
      { name: "twitter:description", content: socialDescription },
      { name: "twitter:image", content: ogImage },
      { name: "twitter:image:alt", content: ogImageAlt },
      { "script:ld+json": softwareApplication },
    ],
    links: [
      { rel: "canonical", href: siteUrl },
      { rel: "stylesheet", href: appCss },
      { rel: "icon", type: "image/svg+xml", href: "/favicon.svg" },
      { rel: "apple-touch-icon", sizes: "180x180", href: "/apple-touch-icon.png" },
    ],
  }),
  shellComponent: RootDocument,
});

function RootDocument({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <head>
        <HeadContent />
      </head>
      <body>
        {children}
        <Scripts />
      </body>
    </html>
  );
}
