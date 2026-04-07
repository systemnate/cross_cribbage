// app/frontend/lib/cable.ts
import { createConsumer } from "@rails/actioncable";
import { getToken } from "./storage";

type Consumer = ReturnType<typeof createConsumer>;

let consumer: Consumer | null = null;

function cableUrl(): string {
  const token = getToken();
  return token ? `/cable?token=${token}` : "/cable";
}

export function getConsumer(): Consumer {
  if (!consumer) consumer = createConsumer(cableUrl());
  return consumer;
}

export function resetConsumer(): void {
  if (consumer) { consumer.disconnect(); consumer = null; }
}
