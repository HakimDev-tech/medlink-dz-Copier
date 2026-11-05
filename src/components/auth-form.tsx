"use client";

import { FormEvent, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

type Mode = "register" | "login" | "doctor";
const messages = {
  fr: {
    patientTitle:"Créer un compte patient", loginTitle:"Connexion", doctorTitle:"Candidature professionnelle",
    doctorIntro:"Renseignez vos informations professionnelles. Votre demande sera examinée manuellement.",
    authIntro:"Authentification sécurisée via Supabase Auth.", email:"Adresse e-mail", password:"Mot de passe",
    fullName:"Nom complet", displayName:"Nom public du professionnel", specialty:"Spécialité", wilaya:"Wilaya",
    reference:"Référence professionnelle", referenceHint:"Indiquez votre référence professionnelle. Les justificatifs seront déposés dans votre espace sécurisé.",
    submitRegister:"Créer mon compte", submitLogin:"Se connecter", submitDoctor:"Envoyer ma demande", busy:"Traitement…",
    needLogin:"Vous devez être connecté pour déposer une candidature.", created:"Compte créé. Vérifiez votre boîte e-mail pour confirmer votre adresse, puis connectez-vous.",
    submitted:"Demande enregistrée. Ajoutez vos justificatifs professionnels pour terminer votre dossier.",
    config:"Configuration Supabase manquante.", connectFirst:"Connectez-vous d'abord avec votre compte.",
    error:"Une erreur est survenue.", already:"Déjà inscrit ?", noAccount:"Pas encore de compte ?",
    createPatient:"Créer un compte patient", createAccount:"Créer un compte", home:"Retour à l'accueil",
  },
  en: {
    patientTitle:"Create a patient account", loginTitle:"Sign in", doctorTitle:"Professional application",
    doctorIntro:"Enter your professional details. Your application will be reviewed manually.",
    authIntro:"Secure authentication powered by Supabase Auth.", email:"Email address", password:"Password",
    fullName:"Full name", displayName:"Public professional name", specialty:"Specialty", wilaya:"Wilaya",
    reference:"Professional registration reference", referenceHint:"Enter your professional reference. Supporting documents can be uploaded securely in your account.",
    submitRegister:"Create account", submitLogin:"Sign in", submitDoctor:"Submit application", busy:"Processing…",
    needLogin:"You must sign in before submitting a professional application.", created:"Account created. Check your inbox to confirm your email address, then sign in.",
    submitted:"Application saved. Upload your professional credentials to complete your file.",
    config:"Supabase configuration is missing.", connectFirst:"Please sign in to your account first.",
    error:"An error occurred.", already:"Already registered?", noAccount:"Don't have an account yet?",
    createPatient:"Create a patient account", createAccount:"Create an account", home:"Back to home",
  },
  ar: {
    patientTitle:"إنشاء حساب مريض", loginTitle:"تسجيل الدخول", doctorTitle:"طلب تسجيل مهني",
    doctorIntro:"أدخل معلوماتك المهنية. ستتم مراجعة طلبك يدوياً.",
    authIntro:"مصادقة آمنة عبر Supabase Auth.", email:"البريد الإلكتروني", password:"كلمة المرور",
    fullName:"الاسم الكامل", displayName:"الاسم المهني الظاهر", specialty:"التخصص", wilaya:"الولاية",
    reference:"مرجع التسجيل المهني", referenceHint:"أدخل مرجعك المهني. يمكنك رفع الوثائق الداعمة بأمان من حسابك.",
    submitRegister:"إنشاء الحساب", submitLogin:"تسجيل الدخول", submitDoctor:"إرسال الطلب", busy:"جارٍ المعالجة…",
    needLogin:"يجب تسجيل الدخول قبل إرسال طلب مهني.", created:"تم إنشاء الحساب. تحقق من بريدك الإلكتروني لتأكيد العنوان ثم سجّل الدخول.",
    submitted:"تم حفظ الطلب. أضف الوثائق المهنية لإكمال ملفك.",
    config:"إعدادات Supabase غير مكتملة.", connectFirst:"يرجى تسجيل الدخول أولاً.",
    error:"حدث خطأ.", already:"لديك حساب بالفعل؟", noAccount:"ليس لديك حساب بعد؟",
    createPatient:"إنشاء حساب مريض", createAccount:"إنشاء حساب", home:"العودة إلى الصفحة الرئيسية",
  },
} as const;

export default function AuthForm({ mode, locale }: { mode: Mode; locale: string }) {
  const router = useRouter();
  const lang = (["fr","en","ar"].includes(locale) ? locale : "fr") as keyof typeof messages;
  const t = messages[lang];
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [userId, setUserId] = useState<string | null>(null);

  useEffect(() => {
    if (mode !== "doctor") return;
    try {
      const supabase = createClient();
      supabase.auth.getUser().then(({ data }) => setUserId(data.user?.id ?? null));
    } catch (e) {
      setError(e instanceof Error ? e.message : t.config);
    }
  }, [mode, t.config]);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true); setError(""); setNotice("");
    const form = new FormData(event.currentTarget);
    try {
      const supabase = createClient();
      if (mode === "register") {
        const { data, error: authError } = await supabase.auth.signUp({
          email: String(form.get("email") ?? ""),
          password: String(form.get("password") ?? ""),
          options: {
            data: { full_name: String(form.get("full_name") ?? ""), preferred_language: locale },
            emailRedirectTo: `${window.location.origin}/auth/callback?next=/${locale}/patient`,
          },
        });
        if (authError) throw authError;
        if (data.session) router.push(`/${locale}`);
        else setNotice(t.created);
      } else if (mode === "login") {
        const { error: authError } = await supabase.auth.signInWithPassword({
          email: String(form.get("email") ?? ""),
          password: String(form.get("password") ?? ""),
        });
        if (authError) throw authError;
        const { data: { user } } = await supabase.auth.getUser();
        const { data: doctor } = user ? await supabase.from("doctors").select("id").eq("user_id", user.id).maybeSingle() : { data: null };
        router.push(doctor ? `/${locale}/professional` : `/${locale}/patient`);
        router.refresh();
      } else {
        const { data } = await supabase.auth.getUser();
        if (!data.user) throw new Error(t.connectFirst);
        const { error: insertError } = await supabase.from("doctors").insert({
          user_id: data.user.id,
          display_name: String(form.get("display_name") ?? ""),
          specialty: String(form.get("specialty") ?? ""),
          wilaya: String(form.get("wilaya") ?? ""),
          registration_reference: String(form.get("registration_reference") ?? ""),
          verification_status: "pending",
        });
        if (insertError) throw insertError;
        setNotice(t.submitted);
        setUserId(data.user.id);
        router.push(`/${locale}/professional`);
        router.refresh();
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : t.error);
    } finally { setBusy(false); }
  }

  const title = mode === "register" ? t.patientTitle : mode === "login" ? t.loginTitle : t.doctorTitle;
  return <section className="form auth-form" lang={lang} dir={lang === "ar" ? "rtl" : "ltr"}>
    <div className="eyebrow">MEDLINK DZ · {mode === "doctor" ? (lang === "ar" ? "التحقق" : lang === "en" ? "VERIFICATION" : "VÉRIFICATION") : (lang === "ar" ? "المصادقة" : lang === "en" ? "AUTHENTICATION" : "AUTHENTIFICATION")}</div>
    <h1>{title}</h1>
    <p>{mode === "doctor" ? t.doctorIntro : t.authIntro}</p>
    {mode === "doctor" && !userId ? <div className="notice">{t.needLogin} <Link href={`/${locale}/login`}>{t.submitLogin}</Link></div> : <form onSubmit={submit} className="form-stack">
      {mode === "register" && <div className="input"><label>{t.fullName}</label><input name="full_name" required minLength={2} autoComplete="name"/></div>}
      {mode !== "doctor" && <div className="input"><label>{t.email}</label><input name="email" type="email" required autoComplete="email"/></div>}
      {mode !== "doctor" && <div className="input"><label>{t.password}</label><input name="password" type="password" required minLength={8} autoComplete={mode === "login" ? "current-password" : "new-password"}/></div>}
      {mode === "doctor" && <>
        <div className="input"><label>{t.displayName}</label><input name="display_name" required maxLength={120}/></div>
        <div className="input"><label>{t.specialty}</label><input name="specialty" required maxLength={100}/></div>
        <div className="input"><label>{t.wilaya}</label><input name="wilaya" required maxLength={80}/></div>
        <div className="input"><label>{t.reference}</label><input name="registration_reference" required maxLength={120}/></div>
        <div className="notice">{t.referenceHint}</div>
      </>}
      <button className="btn primary auth-submit" type="submit" disabled={busy}>{busy ? t.busy : mode === "register" ? t.submitRegister : mode === "login" ? t.submitLogin : t.submitDoctor}</button>
    </form>}
    {error && <p role="alert" className="form-error">{error}</p>}
    {notice && <div className="notice" role="status">{notice}</div>}
    <p className="auth-switch">{mode === "register" ? <>{t.already} <Link href={`/${locale}/login`}>{t.submitLogin}</Link></> : mode === "login" ? <>{t.noAccount} <Link href={`/${locale}/register`}>{t.createPatient}</Link></> : <>{t.needLogin} <Link href={`/${locale}/register`}>{t.createAccount}</Link></>}</p>
    <Link className="btn quiet auth-home" href={`/${locale}`}>{t.home}</Link>
  </section>;
}
