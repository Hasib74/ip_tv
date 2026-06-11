const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// এটি প্রতি ১ মিনিট পর পর চেক করবে ডাটাবেসে কোনো মেসেজ পাঠানোর সময় হয়েছে কি না
exports.checkScheduledNotifications = functions.pubsub.schedule('every 1 minutes').onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const db = admin.firestore();

    // সময় হয়েছে এবং এখনো পাঠানো হয়নি (pending) এমন নোটিফিকেশনগুলো খুঁজবে
    const snapshot = await db.collection('scheduled_notifications')
        .where('scheduledTime', '<=', now)
        .where('status', '==', 'pending')
        .get();

    if (snapshot.empty) {
        console.log('No pending notifications to send.');
        return null;
    }

    const promises = [];

    snapshot.forEach(doc => {
        const data = doc.data();

        // FCM এর মাধ্যমে 'all_users' টপিকে মেসেজ পাঠাবে
        const message = {
            notification: {
                title: data.title,
                body: data.body,
            },
            topic: 'all_users', // আপনার অ্যাপের সব ইউজার এই টপিকে সাবস্ক্রাইব করা আছে
        };

        // নোটিফিকেশন পাঠাবে
        const sendPromise = admin.messaging().send(message)
            .then((response) => {
                console.log('Successfully sent message:', response);
                // পাঠানো হয়ে গেলে স্ট্যাটাস 'sent' করে দিবে যাতে পুনরায় না যায়
                return doc.ref.update({ status: 'sent', sentAt: now });
            })
            .catch((error) => {
                console.log('Error sending message:', error);
            });

        promises.push(sendPromise);
    });


    return Promise.all(promises);
});