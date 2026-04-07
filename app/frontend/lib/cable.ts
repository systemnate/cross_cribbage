// app/frontend/lib/cable.ts
import { createConsumer } from "@rails/actioncable";

type Consumer = ReturnType<typeof createConsumer>;

let consumer: Consumer | null = null;

function cableUrl(): string {
  const token = localStorage.getItem("ccg_player_token");
  return token ? `/cable?token=${token}` : "/cable";
}

export function getConsumer(): Consumer {
  if (!consumer) consumer = createConsumer(cableUrl());
  return consumer;
}

export function resetConsumer(): void {
  if (consumer) { consumer.disconnect(); consumer = null; }
}
