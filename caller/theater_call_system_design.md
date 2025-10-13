# **Theater Play Personalized Call System Design Document**

## **System Overview**
Automated system delivering personalized voice messages to 500 theater participants simultaneously at play conclusion using pre-generated audio files.

## **Architecture Components**

### **APIs & Services**
- **Twilio Voice API:** Call initiation and delivery
- **11Labs:** Voice synthesis from text
- **OpenAI ChatGPT:** Personalized text generation
- **Twilio Lookup API:** Phone number validation

### **Database Schema**
```
participants:
- id
- phone_number (validated)
- audio_file_url
- call_status (pending/completed/failed)
```

## **Workflow**

### **Pre-Event Phase**
1. **Text Generation:** ChatGPT creates personalized messages
2. **Voice Synthesis:** 11Labs converts text to audio files
3. **Audio Hosting:** Store files on CDN with public URLs
4. **Phone Validation:** Twilio Lookup API validates all numbers
5. **Database Population:** Store validated numbers + audio URLs

### **Event Execution**
1. **Screen Message:** "Please turn on your phones for personalized message"
2. **Call Initiation:** Trigger 500 simultaneous calls via Twilio API
3. **TwiML Playback:** Each call plays corresponding audio file
4. **Status Tracking:** Monitor call completion via webhooks

## **Technical Requirements**

### **Twilio Scaling**
- **Rate Limit:** Contact Twilio support for >5 CPS approval
- **Concurrency:** Implement throttling to avoid 429 errors
- **Call Initiation:** `POST /Accounts/{AccountSid}/Calls` with TwiML

### **TwiML Structure**
```xml
<Response>
  <Play>{audio_file_url}</Play>
</Response>
```

### **Phone Validation**
- **Tool:** Twilio Lookup API
- **Process:** Validate all numbers before event
- **Filter:** Remove invalid/landline numbers

## **Edge Cases & Mitigation**

### **Invalid Numbers**
- **Solution:** Twilio Lookup API validation
- **Impact:** Filtered out during pre-event phase

### **Phones Off/Silenced**
- **Mitigation:** Screen message before play end
- **Acceptance:** Some non-answers expected

### **API Rate Limits**
- **Solution:** Request Twilio support for rate increase
- **Implementation:** Throttling + exponential backoff

## **Implementation Priority**
1. Contact Twilio support for rate limit increase
2. Implement phone validation pipeline
3. Build call initiation system with throttling
4. Create screen message for participant preparation

