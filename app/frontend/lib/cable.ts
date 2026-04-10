// app/frontend/lib/cable.ts
import { createConsumer } from "@rails/actioncable";

type Consumer = ReturnType<typeof createConsumer>;

let consumer: Consumer | null = null;

export function getConsumer(): Consumer {
  if (!consumer) consumer = createConsumer("/cable");
  return consumer;
}

export function resetConsumer(): void {
  if (consumer) { consumer.disconnect(); consumer = null; }
}
