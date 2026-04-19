import os

translations = {
    'en': [
        '"add_record" = "Add Record";',
        '"edit_record" = "Edit Record";',
        '"timing" = "Timing";',
        '"date_time" = "Date & Time";',
        '"duration" = "Duration";',
        '"severity" = "Severity";',
        '"triggers" = "Triggers";',
        '"notes" = "Notes";',
        '"location_optional" = "Location (Optional)";',
        '"delete_record" = "Delete Record";',
        '"auto_detected_banner" = "Date, time & duration are locked because this event was automatically detected.";',
        '"add_observations" = "Add any observations, symptoms, or context…";',
        '"location_placeholder" = "e.g. Home, Office, Gym…";',
        '"selected_count" = "%d selected";',
        '"clear" = "Clear";',
        '"save" = "Save";',
        '"min_unit" = "min";',
        '"type" = "Type";',
    ],
    'hi': [
        '"add_record" = "रिकॉर्ड जोड़ें";',
        '"edit_record" = "रिकॉर्ड संपादित करें";',
        '"timing" = "समय";',
        '"date_time" = "दिनांक और समय";',
        '"duration" = "अवधि";',
        '"severity" = "गंभीरता";',
        '"triggers" = "ट्रिगर";',
        '"notes" = "नोट्स";',
        '"location_optional" = "स्थान (वैकल्पिक)";',
        '"delete_record" = "रिकॉर्ड हटाएं";',
        '"auto_detected_banner" = "दिनांक, समय और अवधि लॉक हैं क्योंकि यह घटना स्वचालित रूप से पता चली थी।";',
        '"add_observations" = "कोई भी अवलोकन, लक्षण या संदर्भ जोड़ें…";',
        '"location_placeholder" = "जैसे घर, कार्यालय, जिम…";',
        '"selected_count" = "%d चुने गए";',
        '"clear" = "साफ़ करें";',
        '"save" = "सहेजें";',
        '"min_unit" = "मिनट";',
        '"type" = "प्रकार";',
    ],
    'bn': [
        '"add_record" = "রেকর্ড যোগ করুন";',
        '"edit_record" = "রেকর্ড সম্পাদনা করুন";',
        '"timing" = "সময়";',
        '"date_time" = "তারিখ এবং সময়";',
        '"duration" = "সময়কাল";',
        '"severity" = "তীব্রতা";',
        '"triggers" = "ট্রিগার";',
        '"notes" = "নোট";',
        '"location_optional" = "অবস্থান (ঐচ্ছিক)";',
        '"delete_record" = "রেকর্ড মুছুন";',
        '"auto_detected_banner" = "তারিখ, সময় এবং সময়কাল লক করা আছে কারণ এই ঘটনাটি স্বয়ংক্রিয়ভাবে সনাক্ত হয়েছিল।";',
        '"add_observations" = "যেকোনো পর্যবেক্ষণ, লক্ষণ বা প্রসঙ্গ যোগ করুন…";',
        '"location_placeholder" = "যেমন বাড়ি, অফিস, জিম…";',
        '"selected_count" = "%d নির্বাচিত";',
        '"clear" = "পরিষ্কার করুন";',
        '"save" = "সংরক্ষণ করুন";',
        '"min_unit" = "মিনিট";',
        '"type" = "ধরন";',
    ],
    'ta': [
        '"add_record" = "பதிவு சேர்க்கவும்";',
        '"edit_record" = "பதிவை திருத்தவும்";',
        '"timing" = "நேரம்";',
        '"date_time" = "தேதி மற்றும் நேரம்";',
        '"duration" = "காலம்";',
        '"severity" = "தீவிரம்";',
        '"triggers" = "தூண்டுதல்கள்";',
        '"notes" = "குறிப்புகள்";',
        '"location_optional" = "இடம் (விருப்பத்தேர்வு)";',
        '"delete_record" = "பதிவை நீக்கவும்";',
        '"auto_detected_banner" = "தேதி, நேரம் மற்றும் காலம் பூட்டப்பட்டுள்ளன, ஏனெனில் இந்த நிகழ்வு தானாக கண்டறியப்பட்டது.";',
        '"add_observations" = "கவனிப்புகள், அறிகுறிகள் அல்லது சூழலை சேர்க்கவும்…";',
        '"location_placeholder" = "எ.கா. வீடு, அலுவலகம், ஜிம்…";',
        '"selected_count" = "%d தேர்ந்தெடுக்கப்பட்டது";',
        '"clear" = "அழிக்கவும்";',
        '"save" = "சேமிக்கவும்";',
        '"min_unit" = "நிமிடம்";',
        '"type" = "வகை";',
    ],
    'te': [
        '"add_record" = "రికార్డు జోడించండి";',
        '"edit_record" = "రికార్డు సవరించండి";',
        '"timing" = "సమయం";',
        '"date_time" = "తేదీ మరియు సమయం";',
        '"duration" = "వ్యవధి";',
        '"severity" = "తీవ్రత";',
        '"triggers" = "ట్రిగ్గర్లు";',
        '"notes" = "నోట్లు";',
        '"location_optional" = "స్థానం (ఐచ్ఛికం)";',
        '"delete_record" = "రికార్డు తొలగించండి";',
        '"auto_detected_banner" = "తేదీ, సమయం మరియు వ్యవధి లాక్ చేయబడ్డాయి ఎందుకంటే ఈ సంఘటన స్వయంచాలకంగా గుర్తించబడింది.";',
        '"add_observations" = "ఏవైనా పరిశీలనలు, లక్షణాలు లేదా సందర్భాన్ని జోడించండి…";',
        '"location_placeholder" = "ఉదా. ఇల్లు, కార్యాలయం, జిమ్…";',
        '"selected_count" = "%d ఎంచుకోబడింది";',
        '"clear" = "తొలగించు";',
        '"save" = "సేవ్ చేయండి";',
        '"min_unit" = "నిమిషాలు";',
        '"type" = "రకం";',
    ],
    'mr': [
        '"add_record" = "नोंद जोडा";',
        '"edit_record" = "नोंद संपादित करा";',
        '"timing" = "वेळ";',
        '"date_time" = "तारीख आणि वेळ";',
        '"duration" = "कालावधी";',
        '"severity" = "तीव्रता";',
        '"triggers" = "ट्रिगर";',
        '"notes" = "नोट्स";',
        '"location_optional" = "स्थान (पर्यायी)";',
        '"delete_record" = "नोंद हटवा";',
        '"auto_detected_banner" = "तारीख, वेळ आणि कालावधी लॉक आहेत कारण ही घटना स्वयंचलितपणे आढळली होती.";',
        '"add_observations" = "कोणतेही निरीक्षण, लक्षणे किंवा संदर्भ जोडा…";',
        '"location_placeholder" = "उदा. घर, कार्यालय, जिम…";',
        '"selected_count" = "%d निवडले";',
        '"clear" = "साफ करा";',
        '"save" = "जतन करा";',
        '"min_unit" = "मिनिट";',
        '"type" = "प्रकार";',
    ],
}

base_path = "/Users/gsagrawal/Desktop/Seizcare_SI/Seizcare/Seizcare"

for lang, lines in translations.items():
    file_path = os.path.join(base_path, f"{lang}.lproj/Localizable.strings")
    # Read existing content to avoid duplicates
    with open(file_path, "r") as f:
        existing = f.read()
    
    new_lines = []
    for line in lines:
        key = line.split('"')[1]
        if f'"{key}"' not in existing:
            new_lines.append(line)
    
    if new_lines:
        with open(file_path, "a") as f:
            f.write("\n" + "\n".join(new_lines) + "\n")
        print(f"✅ Added {len(new_lines)} keys to {lang}.lproj")
    else:
        print(f"⏭️  No new keys for {lang}.lproj")

print("Done!")
