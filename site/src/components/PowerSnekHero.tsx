type Feature = {
  title: string;
  description: string;
  icon: "sparkle" | "bolt" | "gauge" | "branch" | "heart";
};

const features: Feature[] = [
  {
    title: "It traces your notch",
    description: "The bolt hugs the exact contour of your MacBook's display - notch and all.",
    icon: "sparkle",
  },
  {
    title: "Only when you plug in",
    description:
      "It fires the instant the charger connects, takes a few laps, then fades on its own.",
    icon: "bolt",
  },
  {
    title: "Zero battery cost",
    description:
      "A one-shot flourish, not a running animation. Switch it on or off anytime in Settings.",
    icon: "gauge",
  },
  {
    title: "Why?",
    description: "We all need a bit more whimsy in our lives. Snekey snek.",
    icon: "heart",
  },
  {
    title: "Open source",
    description: "Have an idea for a feature? Send a contribution.",
    icon: "branch",
  },
];

export function PowerSnekHero() {
  return (
    <div className="bg-page flex min-h-screen w-full flex-col overflow-hidden text-snek-ink">
      <header className="flex items-center gap-[11px] px-6 pt-7 sm:px-12 sm:pt-[30px]">
        <LogoMark />
        <span className="font-display text-wordmark font-bold text-snek-ink">
          Power<span className="text-snek-olive">Snek</span>
        </span>
      </header>

      <main className="hero-main flex flex-1 flex-wrap items-center justify-center gap-12 px-6 pb-14 pt-8 sm:px-12 lg:gap-20">
        <ProductVisual cometSeconds={5} />
        <section className="hero-copy w-[516px] max-w-[92vw]">
          <Badge />
          <h1 className="mb-4 mt-[18px] font-display text-h1 font-bold text-snek-ink">
            Plug in. Watch it snake.
          </h1>
          <p className="max-w-[478px] text-lede text-body">
            The moment your charger connects, a jolt of green lightning streaks around your screen
            and traces the notch - a tiny, electric signal that power is flowing.
          </p>

          <div className="feature-list mb-[34px] mt-[30px] flex flex-col gap-5">
            {features.map((feature) => (
              <FeatureRow key={feature.title} feature={feature} />
            ))}
          </div>

          <a
            className="download-cta bg-cta inline-flex items-center gap-2.5 rounded-pill px-[30px] py-4 text-base font-semibold no-underline shadow-cta transition duration-200 hover:-translate-y-0.5 hover:shadow-[0_20px_38px_-14px_rgba(40,60,12,.8),0_0_0_1px_rgba(195,251,28,.42)_inset] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-snek-olive"
            href="https://github.com/funsaized/PowerSnek/releases"
          >
            <BoltIcon className="h-4 w-4 fill-snek-chartreuse" />
            Download free for macOS
          </a>
        </section>
      </main>
    </div>
  );
}

function LogoMark() {
  return (
    <svg
      aria-hidden="true"
      className="h-10 w-10 origin-[26px_44px] animate-logosnek overflow-visible"
      viewBox="0 0 52 52"
    >
      <defs>
        <linearGradient id="logoGrad" x1="0" y1="1" x2="1" y2="0">
          <stop offset="0" stopColor="#5C7414" />
          <stop offset="1" stopColor="#C3FB1C" />
        </linearGradient>
      </defs>
      <path
        d="M10,46 C10,34 26,38 24,26 C22,16 34,18 36,10"
        fill="none"
        stroke="url(#logoGrad)"
        strokeLinecap="round"
        strokeWidth="8.5"
      />
      <path
        className="animate-energy"
        d="M10,46 C10,34 26,38 24,26 C22,16 34,18 36,10"
        fill="none"
        stroke="#f2ffcf"
        strokeDasharray="6 60"
        strokeLinecap="round"
        strokeWidth="2"
      />
      <circle cx="37" cy="9" r="8" fill="url(#logoGrad)" />
      <circle cx="39" cy="7" r="2.4" fill="#fff" />
      <circle cx="39.7" cy="7.3" r="1" fill="#1a2204" />
      <path
        className="origin-[44px_9px] animate-flick"
        d="M44,9 L44,18 L41,22 M44,18 L47,22"
        fill="none"
        stroke="#2f3d08"
        strokeLinecap="round"
        strokeWidth="1.8"
      />
    </svg>
  );
}

function ProductVisual({ cometSeconds }: { cometSeconds: number }) {
  return (
    <div className="relative">
      <div className="product-scale bg-chassis aspect-[524/366] w-[524px] max-w-[86vw] animate-float rounded-chassis p-2 shadow-chassis">
        <div className="bg-screen relative h-full w-full overflow-hidden rounded-screen">
          <div className="absolute left-1/2 top-0 h-[25px] w-[130px] -translate-x-1/2 rounded-b-[13px] bg-snek-black" />
          <div className="absolute right-[18px] top-2 text-xs tracking-[.3px] text-white/45">
            100% Fri 9:41
          </div>
          <svg
            aria-hidden="true"
            className="absolute inset-0 h-full w-full"
            preserveAspectRatio="none"
            viewBox="0 0 520 360"
          >
            <path
              d="M24,3 L200,3 L200,28 L320,28 L320,3 L496,3 A21,21 0 0 1 517,24 L517,336 A21,21 0 0 1 496,357 L24,357 A21,21 0 0 1 3,336 L3,24 A21,21 0 0 1 24,3 Z"
              fill="none"
              pathLength="2000"
              stroke="rgba(195,251,28,.12)"
              strokeWidth="2.5"
            />
            <path
              className="comet-path"
              d="M24,3 L200,3 L200,28 L320,28 L320,3 L496,3 A21,21 0 0 1 517,24 L517,336 A21,21 0 0 1 496,357 L24,357 A21,21 0 0 1 3,336 L3,24 A21,21 0 0 1 24,3 Z"
              fill="none"
              pathLength="2000"
              stroke="#C3FB1C"
              strokeDasharray="150 1850"
              strokeLinecap="round"
              strokeWidth="4"
              style={{ "--comet-seconds": `${cometSeconds}s` } as CSSProperties}
            />
          </svg>
          <div className="absolute left-[64%] top-[5px] h-[9px] w-[9px] rounded-full bg-[#f7ffdf] shadow-[0_0_10px_3px_rgba(195,251,28,.95)]" />
        </div>
      </div>

      <Mascot />
    </div>
  );
}

function Mascot() {
  return (
    <div className="snake-shadow absolute -bottom-11 -left-[92px] z-[6] w-[236px] max-[640px]:-left-12 max-[640px]:w-[184px]">
      <div className="animate-bob">
        <svg
          aria-hidden="true"
          className="origin-[120px_232px] animate-sway overflow-visible"
          viewBox="0 0 230 250"
          width="100%"
        >
          <defs>
            <linearGradient id="snekBody" x1="0" y1="1" x2="0.6" y2="0">
              <stop offset="0" stopColor="#5C7414" />
              <stop offset="0.55" stopColor="#8CBC1C" />
              <stop offset="1" stopColor="#C3FB1C" />
            </linearGradient>
            <radialGradient id="snekHead" cx="0.4" cy="0.35" r="0.8">
              <stop offset="0" stopColor="#d4ff5c" />
              <stop offset="1" stopColor="#789B16" />
            </radialGradient>
            <radialGradient id="snekAura" cx="0.5" cy="0.5" r="0.5">
              <stop offset="0" stopColor="#AEE01C" stopOpacity="0.30" />
              <stop offset="0.6" stopColor="#AEE01C" stopOpacity="0.10" />
              <stop offset="1" stopColor="#AEE01C" stopOpacity="0" />
            </radialGradient>
          </defs>

          <ellipse
            className="animate-glowpulse"
            cx="112"
            cy="125"
            fill="url(#snekAura)"
            rx="115"
            ry="135"
          />
          <path
            className="origin-[38px_96px] animate-spark"
            d="M30,96 L46,74 L38,92 L52,88 L30,118 L40,98 Z"
            fill="#C3FB1C"
          />
          <path
            className="origin-[203px_118px] animate-spark [animation-delay:1.2s]"
            d="M196,118 L210,98 L203,114 L215,111 L194,140 L203,122 Z"
            fill="#C3FB1C"
          />
          <path
            d="M176,225 C150,228 120,222 122,190 C124,160 168,150 166,118 C164,86 96,96 100,64"
            fill="none"
            stroke="url(#snekBody)"
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth="30"
          />
          <path
            className="animate-energy"
            d="M176,225 C150,228 120,222 122,190 C124,160 168,150 166,118 C164,86 96,96 100,64"
            fill="none"
            opacity="0.9"
            stroke="#f2ffcf"
            strokeDasharray="10 120"
            strokeLinecap="round"
            strokeWidth="5"
          />
          <circle cx="102" cy="54" fill="url(#snekHead)" r="33" />
          <ellipse cx="96" cy="64" fill="#e8ffb0" opacity="0.5" rx="17" ry="13" />
          <g>
            <rect fill="#14180a" height="32" rx="2.5" width="33" x="86" y="-6" />
            <rect fill="#C3FB1C" height="7" width="33" x="86" y="13" />
            <ellipse cx="102" cy="26" fill="#14180a" rx="36" ry="8.5" />
            <ellipse cx="102" cy="24" fill="#1f250e" rx="29" ry="5" />
          </g>
          <g className="origin-[102px_50px] animate-blink">
            <circle cx="90" cy="49" fill="#fff" r="11" />
            <circle cx="114" cy="49" fill="#fff" r="11" />
            <circle cx="93" cy="51" fill="#0a1102" r="5.2" />
            <circle cx="117" cy="51" fill="#0a1102" r="5.2" />
            <circle cx="91" cy="48" fill="#fff" r="2" />
            <circle cx="115" cy="48" fill="#fff" r="2" />
          </g>
          <path
            className="origin-[102px_76px] animate-flick"
            d="M102,74 L102,96 L94,106 M102,96 L110,106"
            fill="none"
            stroke="#e23131"
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth="3.6"
          />
        </svg>
      </div>
    </div>
  );
}

function Badge() {
  return (
    <span className="inline-flex items-center gap-2 rounded-pill bg-[#e7f7b8] px-3.5 py-[7px] text-badge font-bold text-snek-olivedark shadow-[0_0_0_1px_rgba(120,155,22,.25)]">
      <BoltIcon className="h-[11px] w-[11px] animate-zap fill-snek-olive" />
      NEW IN 0.1.0
    </span>
  );
}

function FeatureRow({ feature }: { feature: Feature }) {
  return (
    <div className="flex items-start gap-3.5">
      <span className="bg-chip flex h-10 w-10 flex-none items-center justify-center rounded-chip shadow-chip">
        <FeatureIcon icon={feature.icon} />
      </span>
      <div>
        <div className="text-base font-bold text-[#1c2012]">{feature.title}</div>
        <div className="text-feature text-body-muted">{feature.description}</div>
      </div>
    </div>
  );
}

function FeatureIcon({ icon }: { icon: Feature["icon"] }) {
  if (icon === "sparkle") {
    return (
      <svg aria-hidden="true" className="h-[19px] w-[19px]" viewBox="0 0 24 24">
        <path d="M12 2 L14 9 L21 11 L14 13 L12 22 L10 13 L3 11 L10 9 Z" fill="#f4ffd6" />
      </svg>
    );
  }

  if (icon === "gauge") {
    return (
      <svg aria-hidden="true" className="h-[18px] w-[18px]" fill="none" viewBox="0 0 24 24">
        <circle cx="12" cy="13" r="7.5" stroke="#f4ffd6" strokeWidth="2" />
        <path d="M12 13 L15 10" stroke="#f4ffd6" strokeLinecap="round" strokeWidth="2" />
        <path d="M9 4 H15" stroke="#f4ffd6" strokeLinecap="round" strokeWidth="2" />
      </svg>
    );
  }

  if (icon === "heart") {
    return (
      <svg aria-hidden="true" className="h-[18px] w-[18px]" fill="none" viewBox="0 0 24 24">
        <path
          d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 6.14 4 4 6.4 4c1.54 0 3.04.99 3.56 2.36h2.08C14.56 4.99 16.06 4 17.6 4 20.01 4 22 6.14 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"
          fill="#f4ffd6"
        />
      </svg>
    );
  }

  if (icon === "branch") {
    return (
      <svg aria-hidden="true" className="h-[18px] w-[18px]" fill="none" viewBox="0 0 24 24">
        <path
          d="M7 5v8a4 4 0 0 0 4 4h6M17 17l-3-3M17 17l-3 3M7 5a2 2 0 1 0-4 0 2 2 0 0 0 4 0Zm14 12a2 2 0 1 0-4 0 2 2 0 0 0 4 0Z"
          stroke="#f4ffd6"
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth="2"
        />
      </svg>
    );
  }

  return <BoltIcon className="h-[18px] w-[18px] fill-[#f4ffd6]" />;
}

function BoltIcon({ className }: { className?: string }) {
  return (
    <svg aria-hidden="true" className={className} viewBox="0 0 24 24">
      <path d="M13 2 L4 13 L11 13 L10 22 L20 10 L13 10 Z" />
    </svg>
  );
}
import type { CSSProperties } from "react";
