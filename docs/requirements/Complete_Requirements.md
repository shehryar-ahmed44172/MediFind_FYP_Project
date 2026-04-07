MODULE 1: Authentication & Account Management Module
FR1.1: The system shall allow users to register accounts using email or phone number.
FR1.2: The system shall allow secure login using credentials.
 FR1.3: The system shall support three mobile application roles:
Patient/User
Emergency Responder
Caregiver
The Administrator role shall be accessible only through the secure web-based admin dashboard.
FR1.4: The system shall validate user credentials before granting access.
FR1.5: The system shall allow password reset functionality.
FR1.6: The system shall maintain role-based access control.
FR1.7: The system shall allow the administrator to create, update, deactivate, or delete user accounts.

MODULE 2: Medical Profile Management Module
FR2.1: The system shall allow users to create a digital medical profile.
FR2.2: The system shall allow users to update medical information.
FR2.3: The system shall securely store all medical data.
FR2.4: Medical profile shall include:
Disability type
Allergies
Chronic diseases
Medications
Blood group
FR2.5: The system shall automatically attach the medical profile during SOS activation.
FR2.6: Only assigned responders shall access the patient’s medical profile during an active emergency.
Medical Report Upload Feature
FR2.7: The system shall allow patients to upload medical report images.
FR2.8: The system shall allow patients to upload multiple medical reports.
FR2.9: The system shall securely store and encrypt uploaded medical reports in compliance with HIPAA privacy standards.
FR2.10: Only assigned responders shall view uploaded reports during an active emergency.
FR2.11: The system shall allow patients to delete or update uploaded reports.

MODULE 3: Accessibility & User Interface Module
FR3.1: The system shall provide accessibility modes for disabled users.
FR3.2: Accessibility support shall include:
Text-based interface for deaf users
Large buttons for physically disabled users
FR3.3: The system shall support high-contrast UI mode.
FR3.4: The system shall minimize the number of steps required to trigger SOS.
FR3.5: The system shall provide vibration feedback for accessibility support.
FR3.6: The system shall support speech-impaired users by enabling full emergency activation without requiring voice communication.
FR3.7: The system shall allow predefined emergency text messages for quick communication with responders.

MODULE 4: SOS Emergency & Cancellation Module
FR4.1: The system shall provide a one-tap SOS emergency button.
FR4.2: The system shall allow optional emergency category selection.
Categories include:
Cardiac emergency
Breathing issue
Injury/trauma
Fall/mobility issue
Other emergency
FR4.3: The system shall automatically capture GPS location during SOS activation.
FR4.4: The system shall generate and store an emergency request record.
FR4.5: The system shall allow the patient to cancel the SOS within a specific time window (e.g., 10 seconds) if triggered accidentally. Caregivers shall not cancel an active SOS.
FR4.6: The system shall notify responders immediately if an emergency request is cancelled.

MODULE 5: Responder Management & Assignment Module
FR5.1: The system shall allow responders to register accounts.
FR5.2: The administrator shall verify responder identity before activation.
FR5.3: The system shall identify the nearest available responders using GPS.
FR5.4: The system shall notify up to 6 registered and available responders within a 10 km radius via FCM push notifications (custom UI modal).
FR5.5: The responder shall accept or reject emergency requests.
FR5.6: The system shall assign the first responder who accepts the request and automatically trigger a voice call connection to the patient after 5 seconds.
FR5.7: The system shall automatically close and cancel the request for other responders once assigned.
FR5.8: If a responder rejects a request, it shall disappear for them but remain active for the other responders in the broadcasted batch.
FR5.9: If no responder accepts within 5 minutes, the request shall explicitly expire and disappear.
FR5.10: The system shall escalate the expired request to the next nearest batch of responders using a HIGH priority flag.

MODULE 6: Voice Emergency Alert Module
FR6.1: The system shall generate an automatic voice emergency message.
FR6.2: The voice message shall include:
Emergency type
Medical profile summary
FR6.3: The system shall automatically convert the patient's emergency text and medical summary into speech for the responder to hear while driving.
FR6.4: The system shall send the voice alert to the assigned responder.

MODULE 7: Live Tracking & Navigation Module
FR7.1: The system shall track responder location in real time.
FR7.2: The system shall calculate estimated time of arrival (ETA).
FR7.3: The system shall display responder route using map navigation.
FR7.4: The system shall display emergency status updates to the Patient and Caregiver.

MODULE 8: Caregiver Monitoring Module
FR8.1: The system shall allow users to add and manage caregivers.
FR8.2: The system shall notify caregivers when SOS is triggered.
FR8.3: The caregiver shall receive:
Patient location
Emergency type
Responder status
FR8.4: The caregiver shall monitor live tracking.
FR8.5: The caregiver shall not modify responder assignment.
