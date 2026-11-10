import Link from "next/link";
import { ArrowLeft, ArrowUpRight, Bot, Check, ClipboardList, ShieldCheck, Sparkles, Stethoscope } from "lucide-react";
import styles from "./pricing.module.css";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
export const dynamic = "force-dynamic";

type Locale = "fr" | "ar" | "en";

const content = {
  fr: {
    back: "Retour à MedLink", eyebrow: "MEDLINK DZ · ESPACE PROFESSIONNEL", title: "Des outils adaptés à votre pratique.", intro: "Choisissez le niveau d’accompagnement qui correspond à votre organisation. Le médecin conserve le contrôle de toutes les décisions médicales.",
    period: "/ mois", tax: "Tarifs affichés en dinars algériens (DA).", choose: "Demander cette offre", contact: "L’activation et le paiement seront disponibles après configuration des moyens de paiement.",
    plans: [
      { code: "manual", name: "Pack Manuel", price: "2 500", summary: "Pour organiser votre suivi avec un contrôle entièrement manuel.", icon: "manual", features: ["Gestion des rendez-vous et des patients", "Création manuelle des programmes de suivi", "Planification des rappels et notifications", "Messagerie patient–professionnel", "Compte rendu de consultation et historique"] },
      { code: "ai", name: "Pack AI", price: "5 000", summary: "Pour accompagner vos patients avec un assistant encadré par vos consignes.", icon: "ai", popular: true, features: ["Toutes les fonctionnalités du Pack Manuel", "Assistant patient basé sur les consignes publiées", "Réponses limitées aux informations validées", "Détection des demandes hors périmètre et transfert", "Journalisation des interactions de l’assistant"] },
      { code: "premium", name: "Pack AI Premium", price: "8 000", summary: "Pour préparer une organisation de suivi assistée, avec validation médicale obligatoire.", icon: "premium", features: ["Toutes les fonctionnalités du Pack AI", "Préparation assistée des programmes à partir des instructions du médecin", "Validation obligatoire du médecin avant publication", "Vue de suivi avancée des patients et demandes transférées", "Paramétrage avancé des parcours de suivi"] }
    ],
    guardTitle: "La décision médicale reste la vôtre", guard: "L’assistant ne diagnostique pas, ne prescrit pas et ne modifie jamais un traitement ou un programme publié. Toute proposition générée doit être vérifiée et validée par le professionnel avant d’être communiquée au patient.",
    faqTitle: "Avant de choisir", faq: "Les abonnements sont présentés à titre de grille tarifaire. Le paiement en ligne, la facturation et l’activation automatique ne sont pas encore ouverts. Les offres ne seront activées qu’après la configuration et les tests du prestataire de paiement."
  },
  en: {
    back: "Back to MedLink", eyebrow: "MEDLINK DZ · PROFESSIONAL SPACE", title: "Tools that fit your practice.", intro: "Choose the level of support that matches your workflow. The healthcare professional retains control over every medical decision.",
    period: "/ month", tax: "Prices are shown in Algerian dinars (DZD).", choose: "Request this plan", contact: "Activation and payment will be available once payment services are configured.",
    plans: [
      { code: "manual", name: "Manual Pack", price: "2,500", summary: "Organize patient follow-up with fully manual control.", icon: "manual", features: ["Appointment and patient management", "Manual creation of follow-up plans", "Reminder and notification scheduling", "Patient–professional messaging", "Consultation records and history"] },
      { code: "ai", name: "AI Pack", price: "5,000", summary: "Support patients with an assistant constrained by your approved instructions.", icon: "ai", popular: true, features: ["Everything in the Manual Pack", "Patient assistant grounded in published instructions", "Answers limited to approved information", "Out-of-scope detection and professional handoff", "Assistant interaction audit log"] },
      { code: "premium", name: "AI Premium Pack", price: "8,000", summary: "Prepare assisted follow-up workflows with mandatory clinical approval.", icon: "premium", features: ["Everything in the AI Pack", "Assisted drafting of plans from physician instructions", "Physician approval required before publication", "Advanced overview of patient follow-ups and escalations", "Advanced follow-up workflow configuration"] }
    ],
    guardTitle: "Clinical decisions remain yours", guard: "The assistant does not diagnose, prescribe, or change treatment or a published plan. Every generated suggestion must be reviewed and approved by the professional before being shared with a patient.",
    faqTitle: "Before choosing", faq: "These prices are a proposed pricing schedule. Online payment, invoicing, and automatic activation are not yet enabled. Plans will be activated only after the payment provider is configured and tested."
  },
  ar: {
    back: "العودة إلى MedLink", eyebrow: "MEDLINK DZ · فضاء المهنيين", title: "أدوات تناسب طريقة ممارستكم.", intro: "اختاروا مستوى المرافقة المناسب لتنظيم عملكم. يحتفظ المهني الصحي بالتحكم الكامل في جميع القرارات الطبية.",
    period: "/ شهرياً", tax: "الأسعار بالدينار الجزائري.", choose: "طلب هذه الباقة", contact: "سيصبح التفعيل والدفع متاحين بعد إعداد خدمات الدفع.",
    plans: [
      { code: "manual", name: "الباقة اليدوية", price: "2 500", summary: "تنظيم متابعة المرضى بتحكم يدوي كامل.", icon: "manual", features: ["إدارة المواعيد والمرضى", "إنشاء برامج المتابعة يدوياً", "جدولة التذكيرات والإشعارات", "المراسلة بين المريض والمهني", "تقارير الاستشارة والسجل"] },
      { code: "ai", name: "باقة الذكاء الاصطناعي", price: "5 000", summary: "مرافقة المرضى بمساعد يلتزم بتعليماتكم المعتمدة.", icon: "ai", popular: true, features: ["جميع مزايا الباقة اليدوية", "مساعد للمريض يعتمد على التعليمات المنشورة", "إجابات محصورة في المعلومات المعتمدة", "كشف الطلبات خارج النطاق وإحالتها للمهني", "سجل تفاعلات المساعد"] },
      { code: "premium", name: "باقة الذكاء الاصطناعي المميزة", price: "8 000", summary: "إعداد متابعة مساعدة مع ضرورة المصادقة الطبية.", icon: "premium", features: ["جميع مزايا باقة الذكاء الاصطناعي", "إعداد مساعد لبرامج المتابعة انطلاقاً من تعليمات الطبيب", "مصادقة الطبيب إلزامية قبل النشر", "عرض متقدم لمتابعة المرضى والطلبات المحالة", "إعداد متقدم لمسارات المتابعة"] }
    ],
    guardTitle: "القرار الطبي يبقى من اختصاصكم", guard: "لا يقوم المساعد بالتشخيص أو الوصف أو تعديل العلاج أو برنامج منشور. يجب على المهني مراجعة واعتماد كل اقتراح قبل مشاركته مع المريض.",
    faqTitle: "قبل الاختيار", faq: "تعرض الأسعار ضمن شبكة تسعير مقترحة. الدفع الإلكتروني والفوترة والتفعيل التلقائي غير متاحة بعد. لن يتم تفعيل الباقات إلا بعد إعداد واختبار مزود الدفع."
  }
} as const;

export default async function PricingPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!["fr", "en", "ar"].includes(locale)) notFound();
  const lang = locale as Locale;
  const t = content[lang];
  const rtl = lang === "ar";
  const supabase = await createClient();
  const { data: catalogue } = await supabase.from("subscription_plans").select("code,amount,is_active").eq("is_active", true).order("sort_order");
  return <main className={styles.page} lang={lang} dir={rtl ? "rtl" : "ltr"}>
    <header className={styles.header}>
      <Link href={"/" + lang} className={styles.brand}><span className={styles.brandMark}><Stethoscope size={17}/></span>medlink<span>.</span></Link>
      <Link href={"/" + lang} className={styles.back}><ArrowLeft size={15}/>{t.back}</Link>
    </header>
    <section className={styles.hero}>
      <div className={styles.eyebrow}>{t.eyebrow}</div>
      <h1>{t.title}</h1>
      <p>{t.intro}</p>
    </section>
    <section className={styles.grid} aria-label="Professional plans">
      {(catalogue ?? []).map((plan) => {
        const localized = t.plans.find(item => item.code === plan.code);
        if (!localized) return null;
        const amount = new Intl.NumberFormat(lang === "fr" ? "fr-DZ" : lang === "ar" ? "ar-DZ" : "en").format(plan.amount);
        return <article key={plan.code} className={`${styles.card} ${localized.code === "ai" ? styles.popular : ""}`}>
          {localized.code === "ai" && <div className={styles.popularTag}><Sparkles size={13}/>{lang === "fr" ? "Le plus choisi" : lang === "ar" ? "الخيار المميز" : "Most selected"}</div>}
          <div className={styles.planIcon}>{localized.icon === "manual" ? <ClipboardList size={20}/> : localized.icon === "ai" ? <Bot size={20}/> : <Sparkles size={20}/>}</div>
          <h2>{localized.name}</h2>
          <p className={styles.summary}>{localized.summary}</p>
          <div className={styles.price}><strong>{amount}</strong><span>DA {t.period}</span></div>
          <ul>{localized.features.map(feature => <li key={feature}><Check size={16}/><span>{feature}</span></li>)}</ul>
          <Link className={styles.cta} href={`/${lang}/professional/billing`}>{t.choose}<ArrowUpRight size={15}/></Link>
        </article>;
      })}
    </section>
    <p className={styles.tax}>{t.tax}</p>
    <section className={styles.guard}><ShieldCheck size={22}/><div><h2>{t.guardTitle}</h2><p>{t.guard}</p></div></section>
    <section className={styles.faq}><h2>{t.faqTitle}</h2><p>{t.faq}</p><p>{t.contact}</p></section>
    <footer className={styles.footer}>© 2026 MedLink DZ · {lang === "fr" ? "Les professionnels restent responsables de leurs décisions médicales." : lang === "ar" ? "يبقى المهنيون مسؤولين عن قراراتهم الطبية." : "Healthcare professionals remain responsible for their clinical decisions."}</footer>
  </main>;
}
