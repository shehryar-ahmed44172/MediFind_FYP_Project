# flutter_stripe references Stripe's optional push-provisioning module (Google Pay
# card provisioning), which MediFind does not use or ship. Let R8 ignore it.
-dontwarn com.stripe.android.pushProvisioning.**
