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

/**
 * Callable Firebase Cloud Function: sendCallNotification
 *
 * Sends a high-priority FCM push notification to the receiver device
 * when an audio or video call is initiated.
 */
export const sendCallNotification = onCall(
  {
    cors: true,
  },
  async (request) => {
    // 1. Verify caller authentication
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "The function must be called by an authenticated user."
      );
    }

    const callerUid = request.auth.uid;
    const { receiverUid, callId, callType, callerName, callerZegoUserId, callerPhoto } = request.data || {};

    if (!receiverUid || typeof receiverUid !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "Receiver UID is required."
      );
    }

    if (!callId || typeof callId !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "Call ID is required."
      );
    }

    try {
      // 2. Fetch receiver's Firestore profile to get FCM device token
      const receiverDoc = await admin.firestore().collection("users").doc(receiverUid).get();
      if (!receiverDoc.exists) {
        return { success: false, reason: "user_not_found" };
      }

      const receiverData = receiverDoc.data();
      const fcmToken = receiverData?.fcmToken;

      if (!fcmToken || typeof fcmToken !== "string") {
        console.log(`[FCM] Receiver ${receiverUid} has no registered FCM token.`);
        return { success: false, reason: "no_fcm_token" };
      }

      const now = Date.now();
      const expiresAt = now + 60000; // 60s TTL

      // 3. Construct high-priority FCM message with notification block for terminated state fallback
      const message: admin.messaging.Message = {
        token: fcmToken,
        notification: {
          title: `Incoming ${callType === "video" ? "Video" : "Audio"} Call`,
          body: `${callerName || "User"} is calling you...`,
        },
        data: {
          type: "incoming_call",
          callId: String(callId),
          callType: callType === "video" ? "video" : "audio",
          callerUid: String(callerUid),
          callerName: String(callerName || "User"),
          callerZegoUserId: String(callerZegoUserId || callerUid),
          callerPhoto: String(callerPhoto || ""),
          timestamp: String(now),
          expiresAt: String(expiresAt),
        },
        android: {
          priority: "high",
          ttl: 60 * 1000,
          notification: {
            channelId: "incoming_calls_v2",
            sound: "call_ringtone",
            priority: "max",
            defaultSound: false,
            visibility: "public",
          },
        },
      };

      const response = await admin.messaging().send(message);
      console.log(`[FCM] Sent incoming call notification to ${receiverUid} (messageId: ${response})`);
      return { success: true, messageId: response };
    } catch (err: any) {
      console.error("[FCM] Error sending call notification:", err);
      // Clean up stale or unregistered tokens
      if (
        err?.code === "messaging/registration-token-not-registered" ||
        err?.code === "messaging/invalid-registration-token"
      ) {
        console.log(`[FCM] Removing invalid FCM token for user ${receiverUid}`);
        try {
          await admin.firestore().collection("users").doc(receiverUid).update({
            fcmToken: admin.firestore.FieldValue.delete(),
          });
        } catch (_) {}
      }
      return { success: false, error: err?.message || "Failed to send notification" };
    }
  }
);

/**
 * Callable Firebase Cloud Function: cancelCallNotification
 *
 * Sends a high-priority FCM message to cancel/dismiss the incoming call notification
 * on the receiver device when caller hangs up before answer.
 */
export const cancelCallNotification = onCall(
  {
    cors: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "The function must be called by an authenticated user."
      );
    }

    const { receiverUid, callId } = request.data || {};
    if (!receiverUid || !callId) {
      return { success: false, reason: "missing_parameters" };
    }

    try {
      const receiverDoc = await admin.firestore().collection("users").doc(receiverUid).get();
      if (!receiverDoc.exists) return { success: false, reason: "user_not_found" };

      const fcmToken = receiverDoc.data()?.fcmToken;
      if (!fcmToken) return { success: false, reason: "no_token" };

      const message: admin.messaging.Message = {
        token: fcmToken,
        data: {
          type: "call_cancelled",
          callId: String(callId),
          timestamp: String(Date.now()),
        },
        android: {
          priority: "high",
          ttl: 10 * 1000,
        },
      };

      await admin.messaging().send(message);
      console.log(`[FCM] Sent call cancelled notification for ${callId} to ${receiverUid}`);
      return { success: true };
    } catch (err: any) {
      console.error("[FCM] Error cancelling call notification:", err);
      return { success: false, error: err?.message };
    }
  }
);
