"use client";

import Link from "next/link";
import { GitHubMark, githubUrl } from "./shared";

export function LandingFooter() {
  return (
    <footer className="bg-[#0a0d12] text-white">
      <div className="mx-auto max-w-[1320px] px-4 sm:px-6 lg:px-8">
        <div className="flex flex-col gap-3 border-t border-white/10 py-6 text-[13px] text-white/46 sm:flex-row sm:items-center sm:justify-between">
          <p>powered by multica</p>
          <Link
            href={githubUrl}
            target="_blank"
            rel="noreferrer"
            className="inline-flex items-center gap-2 text-white/60 transition-colors hover:text-white"
          >
            <GitHubMark className="size-4" />
            GitHub
          </Link>
        </div>
      </div>
    </footer>
  );
}
