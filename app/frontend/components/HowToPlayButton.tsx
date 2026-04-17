import React, { useState, useEffect, useRef } from "react";

export function HowToPlayButton() {
  const [open, setOpen] = useState(false);
  const triggerRef = useRef<HTMLButtonElement>(null);

  const handleClose = () => {
    setOpen(false);
    triggerRef.current?.focus();
  };

  return (
    <>
      <button
        ref={triggerRef}
        type="button"
        onClick={() => setOpen(true)}
        aria-label="How to play"
        className="fixed bottom-3 right-3 z-40 w-10 h-10 rounded-full bg-slate-800 hover:bg-slate-700 border-2 border-slate-600 text-slate-200 text-lg font-bold shadow-lg transition-colors flex items-center justify-center"
      >
        ?
      </button>
      {open && <HowToPlayModal onClose={handleClose} />}
    </>
  );
}

function HowToPlayModal({ onClose }: { onClose: () => void }) {
  const closeRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    closeRef.current?.focus();
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  return (
    <div
      onClick={onClose}
      className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4"
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-label="How to play Cross Cribbage"
        onClick={(e) => e.stopPropagation()}
        className="bg-slate-900 border border-slate-700 rounded-xl p-6 max-w-lg w-full max-h-[90vh] overflow-y-auto relative"
      >
        <button
          ref={closeRef}
          type="button"
          onClick={onClose}
          aria-label="Close"
          className="absolute top-3 right-3 w-8 h-8 rounded hover:bg-slate-800 text-slate-400 hover:text-slate-100 text-2xl leading-none flex items-center justify-center"
        >
          ×
        </button>

        <h2 className="text-yellow-400 font-black text-xl mb-4">How to play Cross Cribbage</h2>

        <p className="text-slate-400 text-sm">Content coming next task.</p>
      </div>
    </div>
  );
}
