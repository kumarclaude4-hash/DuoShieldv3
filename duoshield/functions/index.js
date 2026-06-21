/**
 * DuoShield Firebase Cloud Functions
 * 
 * Trigger: onDocumentCreated on /conversations/{convId}/messages/{msgId}
 * Action: Send FCM notification to recipient with no message content
 * 
 * Security: Notifications never contain sender name or message preview
 */

const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {initializeApp} = require("firebase-admin/app");

// Initialize Firebase Admin SDK
initializeApp();

const db = getFirestore();
const messaging = getMessaging();

/**
 * Cloud Function: sendMessageNotification
 * 
 * Triggered when a new message document is created in Firestore.
 * Sends a silent FCM notification to the message recipient.
 * 
 * The notification contains NO message content - only a trigger for the app
 * to fetch the encrypted message from Firestore.
 */
exports.sendMessageNotification = onDocumentCreated(
  {
    document: "conversations/{conversationId}/messages/{messageId}",
    region: "us-central1",
  },
  async (event) => {
    const {conversationId, messageId} = event.params;
    const messageData = event.data.data();

    // Validate message data
    if (!messageData) {
      console.log(`No data for message ${messageId}`);
      return;
    }

    const senderId = messageData.senderId;
    if (!senderId) {
      console.log(`No senderId for message ${messageId}`);
      return;
    }

    try {
      // Get conversation to find participants
      const conversationDoc = await db
        .collection("conversations")
        .doc(conversationId)
        .get();

      if (!conversationDoc.exists) {
        console.log(`Conversation ${conversationId} not found`);
        return;
      }

      const conversationData = conversationDoc.data();
      const participants = conversationData.participants || [];

      // Find recipient (the participant who is not the sender)
      const recipientId = participants.find((uid) => uid !== senderId);

      if (!recipientId) {
        console.log(`No recipient found for message ${messageId}`);
        return;
      }

      // Get recipient's FCM token
      const userDoc = await db
        .collection("users")
        .doc(recipientId)
        .get();

      if (!userDoc.exists) {
        console.log(`Recipient ${recipientId} not found`);
        return;
      }

      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;

      if (!fcmToken) {
        console.log(`No FCM token for recipient ${recipientId}`);
        return;
      }

      // Send FCM notification
      // IMPORTANT: Notification contains NO message content
      // Title and body are generic - never include sender name or message preview
      const message = {
        token: fcmToken,
        notification: {
          title: "DuoShield",
          body: "New message",
        },
        data: {
          conversationId: conversationId,
          messageId: messageId,
          type: "new_message",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "duoshield_messages",
            sound: "default",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      const response = await messaging.send(message);
      console.log(
        `Notification sent for message ${messageId} to ${recipientId}: ${response}`
      );
    } catch (error) {
      // Handle stale FCM tokens gracefully
      if (error.code === "messaging/registration-token-not-registered" ||
          error.code === "messaging/invalid-registration-token") {
        console.log(`Stale FCM token for recipient, removing: ${error.message}`);
        
        // Try to find and remove the stale token
        try {
          const recipientId = participants.find((uid) => uid !== senderId);
          if (recipientId) {
            await db
              .collection("users")
              .doc(recipientId)
              .update({fcmToken: null});
            console.log(`Removed stale FCM token for user ${recipientId}`);
          }
        } catch (cleanupError) {
          console.log(`Failed to cleanup stale token: ${cleanupError.message}`);
        }
      } else {
        console.error(`Error sending notification: ${error.message}`);
      }
    }
  }
);

/**
 * Cloud Function: cleanupStaleTokens
 * 
 * Scheduled function to clean up stale FCM tokens.
 * Runs daily to remove tokens that haven't been updated in 30 days.
 * 
 * Note: This requires the Cloud Scheduler API to be enabled.
 * Uncomment and deploy if scheduled cleanup is desired.
 */
// const {onSchedule} = require("firebase-functions/v2/scheduler");
// 
// exports.cleanupStaleTokens = onSchedule(
//   {
//     schedule: "0 2 * * *", // Daily at 2 AM
//     region: "us-central1",
//   },
//   async (event) => {
//     const thirtyDaysAgo = new Date();
//     thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
//     
//     const staleUsers = await db
//       .collection("users")
//       .where("lastTokenUpdate", "<", thirtyDaysAgo)
//       .get();
//     
//     const batch = db.batch();
//     let count = 0;
//     
//     staleUsers.forEach((doc) => {
//       batch.update(doc.ref, {fcmToken: null});
//       count++;
//     });
//     
//     if (count > 0) {
//       await batch.commit();
//       console.log(`Cleaned up ${count} stale FCM tokens`);
//     }
//   }
// );

/**
 * Cloud Function: userPresenceOnAuth
 * 
 * Triggered when a user signs in anonymously.
 * Ensures the user document exists with basic fields.
 */
exports.userPresenceOnAuth = require("firebase-functions/v2/identity").beforeUserCreated(
  {
    region: "us-central1",
  },
  async (event) => {
    const user = event.data;
    
    try {
      // Create or update user document
      await db.collection("users").doc(user.uid).set(
        {
          createdAt: new Date(),
          lastLoginAt: new Date(),
        },
        {merge: true}
      );
      
      console.log(`User document ensured for ${user.uid}`);
    } catch (error) {
      console.error(`Error ensuring user document: ${error.message}`);
    }
  }
);
