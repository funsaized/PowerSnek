import { createFileRoute } from "@tanstack/react-router";
import { PowerSnekHero } from "../components/PowerSnekHero";

export const Route = createFileRoute("/")({
  component: Home,
});

function Home() {
  return <PowerSnekHero />;
}
