export type CarePlanContext = {
  title: string;
  instructions: string;
  starts_on: string;
  ends_on: string | null;
  events: Array<{ event_at: string; label: string; instruction: string | null }>;
};
export type AgentLocale = "fr" | "en" | "ar";
export type AgentResult = {
  intent: "plan_lookup" | "schedule_lookup" | "out_of_scope" | "urgent_escalation" | "unknown";
  outcome: "answered_from_plan" | "human_handoff" | "refused";
  answer: string;
  handoff: boolean;
  safetyFlags: string[];
};

const copy = {
  fr: {
    greeting: "Bonjour. Je peux vous aider à retrouver les consignes et les rappels de votre programme de suivi validé.",
    urgent: "Votre message peut nécessiter une évaluation rapide. Je ne peux pas évaluer une urgence. Contactez immédiatement les services d’urgence locaux ou votre professionnel de santé. Votre demande a été signalée au professionnel.",
    out: "Je ne peux pas établir de diagnostic, interpréter des symptômes, recommander un médicament, modifier une dose ou proposer un traitement. Votre professionnel de santé doit répondre à cette demande. Elle lui a été signalée.",
    planName: (context: CarePlanContext) => "Le titre de votre programme est : " + context.title,
    period: (context: CarePlanContext) => "Programme : " + context.title + "\nDébut : " + new Date(context.starts_on + "T12:00:00Z").toLocaleDateString("fr-DZ",{timeZone:"Africa/Algiers"}) + (context.ends_on ? "\nFin : " + new Date(context.ends_on + "T12:00:00Z").toLocaleDateString("fr-DZ",{timeZone:"Africa/Algiers"}) : ""),
    schedule: (events: CarePlanContext["events"]) => events.length
      ? "Rappels enregistrés dans votre programme :\n" + events.map(e => "• " + e.label + " — " + new Date(e.event_at).toLocaleString("fr-DZ",{timeZone:"Africa/Algiers"}) + (e.instruction ? "\n  " + e.instruction : "")).join("\n")
      : "Aucun rappel futur n’est enregistré dans ce programme.",
    found: (snippets: string[]) => "Voici les passages correspondants de votre programme validé :\n" + snippets.map(s => "• " + s).join("\n"),
    unknown: "Je ne trouve pas cette information dans les consignes publiées. Je préfère ne pas l’interpréter. Votre demande a été transmise à votre professionnel pour examen."
  },
  en: {
    greeting: "Hello. I can help you find the instructions and reminders in your approved follow-up plan.",
    urgent: "Your message may require prompt assessment. I cannot assess emergencies. Contact local emergency services or your healthcare professional immediately. Your request has been flagged for the professional.",
    out: "I cannot diagnose, interpret symptoms, recommend medication, change a dose, or suggest treatment. Your healthcare professional must answer this request. It has been flagged for them.",
    planName: (context: CarePlanContext) => "Your plan is titled: " + context.title,
    period: (context: CarePlanContext) => "Plan: " + context.title + "\nStart: " + new Date(context.starts_on + "T12:00:00Z").toLocaleDateString("en-US",{timeZone:"Africa/Algiers"}) + (context.ends_on ? "\nEnd: " + new Date(context.ends_on + "T12:00:00Z").toLocaleDateString("en-US",{timeZone:"Africa/Algiers"}) : ""),
    schedule: (events: CarePlanContext["events"]) => events.length
      ? "Reminders registered in your plan:\n" + events.map(e => "• " + e.label + " — " + new Date(e.event_at).toLocaleString("en-US",{timeZone:"Africa/Algiers"}) + (e.instruction ? "\n  " + e.instruction : "")).join("\n")
      : "No future reminder is registered in this plan.",
    found: (snippets: string[]) => "Relevant passages from your approved plan:\n" + snippets.map(s => "• " + s).join("\n"),
    unknown: "I cannot find this information in the published instructions, so I will not infer an answer. Your request has been sent to your healthcare professional for review."
  },
  ar: {
    greeting: "مرحباً. يمكنني مساعدتك في العثور على التعليمات والتذكيرات في برنامج المتابعة المعتمد.",
    urgent: "قد تتطلب رسالتك تقييماً عاجلاً. لا يمكنني تقييم الحالات الطارئة. اتصل فوراً بخدمات الطوارئ المحلية أو بالمهني الصحي. تمت إحالة طلبك إلى المهني.",
    out: "لا يمكنني التشخيص أو تفسير الأعراض أو اقتراح دواء أو تغيير جرعة أو تقديم علاج. يجب أن يجيب المهني الصحي عن هذا الطلب. تمت إحالته إليه.",
    planName: (context: CarePlanContext) => "عنوان برنامجك هو: " + context.title,
    period: (context: CarePlanContext) => "البرنامج: " + context.title + "\nالبداية: " + new Date(context.starts_on + "T12:00:00Z").toLocaleDateString("ar-DZ",{timeZone:"Africa/Algiers"}) + (context.ends_on ? "\nالنهاية: " + new Date(context.ends_on + "T12:00:00Z").toLocaleDateString("ar-DZ",{timeZone:"Africa/Algiers"}) : ""),
    schedule: (events: CarePlanContext["events"]) => events.length
      ? "التذكيرات المسجلة في برنامجك:\n" + events.map(e => "• " + e.label + " — " + new Date(e.event_at).toLocaleString("ar-DZ",{timeZone:"Africa/Algiers"}) + (e.instruction ? "\n  " + e.instruction : "")).join("\n")
      : "لا يوجد تذكير مستقبلي مسجل في هذا البرنامج.",
    found: (snippets: string[]) => "المقاطع المطابقة من برنامجك المعتمد:\n" + snippets.map(s => "• " + s).join("\n"),
    unknown: "لم أجد هذه المعلومة في التعليمات المنشورة، لذلك لن أستنتج إجابة. تمت إحالة طلبك إلى المهني الصحي لمراجعته."
  }
} as const;

const stopWords = new Set([
  "a","à","au","aux","avec","ce","ces","dans","de","des","du","elle","en","et","il","je","la","le","les","ma","mais","me","mon","ou","par","pas","pour","que","quel","quelle","quels","quelles","qui","sa","se","son","sur","un","une","vos","votre","mes","est","dois","doit","faire","comment","quoi","quand","où","the","a","an","and","are","as","at","be","can","do","does","for","from","how","i","in","is","it","my","of","on","or","please","should","the","to","what","when","where","which","with","your","you","هل","ما","ماذا","كيف","متى","أين","من","في","على","إلى","عن","هذا","هذه","هو","هي","هل","و","من","مع","لي","لدي"
]);

function normalize(value: string): string {
  return value.toLocaleLowerCase()
    .normalize("NFKD")
    .replace(/[\u064B-\u065F\u0670]/g, "")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^\p{L}\p{N}\s]/gu, " ")
    .replace(/\s+/g, " ")
    .trim();
}
function tokens(value: string): string[] {
  return [...new Set(normalize(value).split(" ").filter(t => t.length > 1 && !stopWords.has(t)))];
}
function retrieveApprovedPassages(question: string, instructions: string): string[] {
  const queryTokens = tokens(question);
  if (queryTokens.length === 0) return [];
  const chunks = instructions
    .split(/\n+|(?<=[.!?؟؛])\s+/u)
    .map(part => part.replace(/^\s*[-•*\d.)]+\s*/, "").trim())
    .filter(part => part.length >= 12);
  const ranked = chunks.map((text, index) => {
    const chunkTokens = new Set(tokens(text));
    const overlap = queryTokens.filter(token => chunkTokens.has(token)).length;
    const coverage = overlap / queryTokens.length;
    return { text, index, overlap, coverage };
  }).filter(item => item.overlap > 0)
    .sort((a, b) => b.coverage - a.coverage || b.overlap - a.overlap || a.index - b.index);
  if (!ranked.length) return [];
  const best = ranked[0];
  // Conservative lexical retrieval: require at least two shared terms or a strong single-token match.
  if (best.overlap < 2 && (queryTokens.length > 1 || best.coverage < 1)) return [];
  return ranked.filter(item => item.coverage >= Math.max(0.5, best.coverage - 0.2)).slice(0, 4).map(item => item.text);
}

export function answerFromCarePlan(message: string, context: CarePlanContext, locale: AgentLocale): AgentResult {
  const lang = copy[locale];
  const normalized = normalize(message);
  const greeting = /^(bonjour|bonsoir|salut|hello|hi|hey|good morning|good evening|merci|thanks|thank you|شكرا|السلام عليكم|مرحبا)$/i.test(normalized);
  if (greeting) return { intent: "unknown", outcome: "refused", answer: lang.greeting, handoff: false, safetyFlags: [] };

  const urgent = /(urgence|urgent|emergency|chest pain|pain in chest|difficulty breathing|not breathing|no breathing|cant breathe|can t breathe|cannot breathe|unable to breathe|shortness of breath|choking|severe bleeding|heavy bleeding|unconscious|loss of consciousness|fainting|seizure|convulsion|stroke|face droop|one sided weakness|sudden weakness|facial drooping|severe allergic reaction|anaphylaxis|suicid|douleur thoracique|douleur poitrine|douleur dans la poitrine|difficulte a respirer|difficulte respirer|essoufflement|respire difficilement|manque d air|manque dair|ne respire plus|arret respiratoire|etouffement|perte de connaissance|perte connaissance|convulsion|saignement abondant|saignement important|faiblesse soudaine|paralysie soudaine|reaction allergique grave|افكار انتحارية|طوارئ|نزيف حاد|نزيف شديد|صعوبة التنفس|ضيق التنفس|لا يتنفس|توقف التنفس|اختناق|ألم الصدر|ألم في الصدر|فقدان الوعي|فقد الوعي|تشنج|سكتة دماغية|جلطة دماغية|ضعف مفاجئ|شلل مفاجئ|حساسية شديدة)/i.test(normalized);
  if (urgent) return { intent: "urgent_escalation", outcome: "human_handoff", answer: lang.urgent, handoff: true, safetyFlags: ["possible_urgent_symptom", "human_escalation"] };

  const clinical = /(diagnos|symptom|symptome|medicine|medication|\bmeds\b|drug|dose|dosage|pill|prescription|treatment|traitement|medicament|posologie|antibiotic|insulin|inhaler|injection|tablet|capsule|anticoagulant|blood thinner|vaccine|vaccination|stop taking|skip a dose|missed dose|forgot to take|increase.*dose|decrease.*dose|change.*dose|pain|fever|rash|headache|vomit|nausea|diarrhea|blood pressure|blood sugar|glucose|swelling|infection|douleur|fievre|eruption|mal de tete|vomissement|nausee|diarrhee|tension|glycemie|gonflement|antibiotique|insuline|inhalateur|comprime|gelule|anticoagulant|vaccin|arreter|oublie|prendre.*medicament|augmenter.*dose|diminuer.*dose|جرعة|دواء|تشخيص|علاج|أعراض|اعراض|وصفة|اعراض جانبية|حمى|سخونة|صداع|قيء|غثيان|إسهال|اسهال|ضغط الدم|سكر الدم|تورم|التهاب|مضاد حيوي|أنسولين|بخاخ|حقنة|إبرة|حبوب|أقراص|مميع الدم|لقاح|إيقاف الدواء|نسيت الجرعة|تغيير الجرعة)/i.test(normalized);
  if (clinical) return { intent: "out_of_scope", outcome: "human_handoff", answer: lang.out, handoff: true, safetyFlags: ["clinical_advice_blocked", "human_escalation"] };

  const schedule = /(remind|reminder|follow up|follow-up|schedule|how often|frequency|rappel|rappeler|suivi|frequence|combien de fois|تذكير|التذكير|المتابعة|متابعة|كم مرة|كل كم)/i.test(normalized);
  if (schedule) return { intent: "schedule_lookup", outcome: "answered_from_plan", answer: lang.schedule(context.events), handoff: false, safetyFlags: [] };

  const planNameQuestion = /(plan name|what is my plan called|title of my plan|nom du programme|titre du programme|comment s appelle.*programme|اسم البرنامج|ما اسم البرنامج)/i.test(normalized);
  if (planNameQuestion) return { intent: "plan_lookup", outcome: "answered_from_plan", answer: lang.planName(context), handoff: false, safetyFlags: [] };

  const periodQuestion = /(start date|beginning|when does.*start|when.*start|end date|when does.*end|date de debut|date du debut|quand commence|debut du programme|date de fin|quand se termine|بداية البرنامج|متى يبدأ|تاريخ البداية|نهاية البرنامج|متى ينتهي|تاريخ النهاية)/i.test(normalized);
  if (periodQuestion) return { intent: "plan_lookup", outcome: "answered_from_plan", answer: lang.period(context), handoff: false, safetyFlags: [] };

  const approvedContext = [context.title, context.instructions, ...context.events.map(event => [event.label,event.instruction].filter(Boolean).join(". "))].join("\n");
  const passages = retrieveApprovedPassages(message, approvedContext);
  if (passages.length) return { intent: "plan_lookup", outcome: "answered_from_plan", answer: lang.found(passages), handoff: false, safetyFlags: [] };

  return { intent: "unknown", outcome: "human_handoff", answer: lang.unknown, handoff: true, safetyFlags: ["answer_not_found_in_approved_plan", "human_escalation"] };
}
