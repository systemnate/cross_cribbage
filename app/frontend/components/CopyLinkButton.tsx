import React, { useState } from "react";

export function CopyLinkButton({ gameId }: { gameId: string }) {
  const [copied, setCopied] = useState(false);
  const link = `${window.location.origin}/join/${gameId}`;

  function handleCopy() {
    navigator.clipboard.writeText(link).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    });
  }

  return (
    <div className="flex flex-col items-center gap-2 w-full max-w-sm">
      <div className="flex items-center gap-2 w-full bg-slate-800 border border-slate-600 rounded-lg px-3 py-2">
        <span className="flex-1 font-mono text-yellow-300 text-xs truncate select-all">
          {link}
        </span>
        <button
          onClick={handleCopy}
          className="flex-shrink-0 rounded bg-yellow-400 hover:bg-yellow-300 text-slate-900 font-semibold text-xs px-3 py-1 transition-colors"
        >
          {copied ? "Copied!" : "Copy"}
        </button>
      </div>
    </div>
  );
}
