import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";
// @ts-ignore - CommonJS module without bundled type declaration
import { generateToken04 } from "./zegoServerAssistant";

// Initialize Firebase Admin SDK
admin.initializeApp();

// Define secret managed via Firebase / Google Cloud Secret Manager
const zegoServerSecret = defineSecret("ZEGO_SERVER_SECRET");

/**
 * Callable Firebase Cloud Function: getZegoToken
 *
 * Requirements:
 * 1. Requires valid Firebase Authentication.
 * 2. Obtains the user ID directly from the verified auth context (request.auth.uid).
 * 3. Never returns or exposes ServerSecret or AppSign.
 * 4. Generates a secure Token04 using ZEGOCLOUD's official algorithm.
 */
export const getZegoToken = onCall(
  {
    secrets: [zegoServerSecret],
    cors: true,
  },
  async (request) => {
    // 1. Verify user authentication
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "The function must be called by an authenticated user."
      );
    }

    const userId = request.auth.uid;
    if (!userId || typeof userId !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "Authenticated user ID is invalid."
      );
    }

    // 2. Retrieve credentials securely from Secret Manager or environment
    let serverSecret = "";
    try {
      serverSecret = zegoServerSecret.value();
    } catch {
      serverSecret = process.env.ZEGO_SERVER_SECRET || "";
    }

    const appIdRaw = process.env.ZEGO_APP_ID || "0";
    const appId = parseInt(appIdRaw, 10);

    // 3. Verify server-side configuration
    if (!appId || !serverSecret || serverSecret === "YOUR_ZEGO_SERVER_SECRET") {
      throw new HttpsError(
        "failed-precondition",
        "ZEGOCLOUD AppID or ServerSecret is not properly configured on the server. Please set ZEGO_SERVER_SECRET in Firebase Secret Manager and ZEGO_APP_ID in environment."
      );
    }

    // 4. Generate token with 1 hour validity (3600 seconds)
    const effectiveTimeInSeconds = 3600;
    const payload = "";

    try {
      const token = generateToken04(
        appId,
        userId,
        serverSecret,
        effectiveTimeInSeconds,
        payload
      );

      // Return only what the client needs - NEVER return serverSecret or appSign
      return {
        appId,
        userId,
        token,
        expiresIn: effectiveTimeInSeconds,
      };
    } catch (err: any) {
      console.error("ZEGOCLOUD token generation error:", err?.errorMessage || err);
      throw new HttpsError(
        "internal",
        "Failed to generate ZEGOCLOUD authentication token."
      );
    }
  }
);
