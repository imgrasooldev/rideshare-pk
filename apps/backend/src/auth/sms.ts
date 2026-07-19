// SMS/WhatsApp delivery adapter (rule 9: provider is config, not code).
// Real aggregator implementations (Twilio, VeevoTech, ...) are queue-backed
// jobs added with the notifications module; dev mode logs the code.
export interface SmsSender {
  sendOtp(phone: string, code: string): Promise<void>;
}

export class DevLogSmsSender implements SmsSender {
  async sendOtp(phone: string, code: string): Promise<void> {
    console.log(JSON.stringify({ level: "info", msg: "dev OTP (not sent)", phone, code }));
  }
}
