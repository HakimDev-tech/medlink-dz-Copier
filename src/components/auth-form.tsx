"use client";

import { FormEvent, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

type Mode = "register" | "login" | "doctor";
export default function AuthForm({ mode, locale }: { mode: Mode; locale: string }) {
  const router = useRouter();
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
      setError(e instanceof Error ? e.message : "Configuration Supabase manquante.");
    }
  }, [mode]);

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
        else setNotice("Compte créé. Vérifiez votre boîte e-mail pour confirmer l'adresse, puis connectez-vous.");
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
        if (!data.user) throw new Error("Connectez-vous d'abord avec votre compte.");
        const { error: insertError } = await supabase.from("doctors").insert({
          user_id: data.user.id,
          display_name: String(form.get("display_name") ?? ""),
          specialty: String(form.get("specialty") ?? ""),
          wilaya: String(form.get("wilaya") ?? ""),
          registration_reference: String(form.get("registration_reference") ?? ""),
          verification_status: "pending",
        });
        if (insertError) throw insertError;
        setNotice("Demande enregistrée. Ajoutez vos justificatifs professionnels pour terminer le dossier.");
        setUserId(data.user.id);
        router.push(`/${locale}/professional`);
        router.refresh();
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : "Une erreur est survenue.");
    } finally { setBusy(false); }
  }

  const title = mode === "register" ? "Créer un compte patient" : mode === "login" ? "Connexion" : "Candidature professionnelle";
  return <section className="form">
    <div className="eyebrow">MEDLINK DZ · {mode === "doctor" ? "VERIFICATION" : "AUTHENTIFICATION"}</div>
    <h1>{title}</h1>
    <p>{mode === "doctor" ? "Soumettez les informations professionnelles. La demande reste en attente d'une vérification manuelle." : "Authentification sécurisée via Supabase Auth."}</p>
    {mode === "doctor" && !userId ? <div className="notice">Vous devez être connecté pour soumettre une demande professionnelle. <Link href={`/${locale}/login`}>Se connecter</Link></div> : <form onSubmit={submit}>
      {mode === "register" && <div className="input"><label>Nom complet</label><input name="full_name" required minLength={2} autoComplete="name"/></div>}
      {mode !== "doctor" && <div className="input"><label>Adresse e-mail</label><input name="email" type="email" required autoComplete="email"/></div>}
      {mode !== "doctor" && <div className="input"><label>Mot de passe</label><input name="password" type="password" required minLength={8} autoComplete={mode === "login" ? "current-password" : "new-password"}/></div>}
      {mode === "doctor" && <>
        <div className="input"><label>Nom public du professionnel</label><input name="display_name" required maxLength={120}/></div>
        <div className="input"><label>Spécialité</label><input name="specialty" required maxLength={100}/></div>
        <div className="input"><label>Wilaya</label><input name="wilaya" required maxLength={80}/></div>
        <div className="input"><label>Référence professionnelle (sans document)</label><input name="registration_reference" required maxLength={120}/></div>
        <div className="notice">Ne téléversez aucun document d'identité ou dossier médical dans cette version. La référence sera contrôlée manuellement.</div>
      </>}
      <button className="btn primary" type="submit" disabled={busy}>{busy ? "Traitement…" : mode === "register" ? "Créer mon compte" : mode === "login" ? "Se connecter" : "Envoyer ma demande"}</button>
    </form>}
    {error && <p role="alert" style={{color:"#a33"}}>{error}</p>}
    {notice && <div className="notice" role="status">{notice}</div>}
    <p>{mode === "register" ? <>Déjà inscrit ? <Link href={`/${locale}/login`}>Se connecter</Link></> : mode === "login" ? <>Pas encore de compte ? <Link href={`/${locale}/register`}>Créer un compte patient</Link></> : <>Vous avez besoin d'un compte ? <Link href={`/${locale}/register`}>Créer un compte</Link></>}</p>
    <Link className="btn quiet" href={`/${locale}`}>Retour à l'accueil</Link>
  </section>;
}
