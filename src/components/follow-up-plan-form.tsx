"use client";

import { useState, type FormEvent } from "react";
import { createClient } from "@/lib/supabase/client";

type AppointmentOption={id:string;patient_id:string;starts_at:string};
export default function FollowUpPlanForm({doctorId,appointments}:{doctorId:string;appointments:AppointmentOption[]}) {
  const [busy,setBusy]=useState(false);
  const [message,setMessage]=useState("");
  const [draftId,setDraftId]=useState<string|null>(null);
  async function submit(event:FormEvent<HTMLFormElement>) {
    event.preventDefault();setBusy(true);setMessage("");
    try {
      const supabase=createClient();
      const form=new FormData(event.currentTarget);
      const patientId=String(form.get("appointment")||"");
      const appointment=appointments.find(a=>a.id===patientId);
      if(!appointment) throw new Error("Sélectionnez un rendez-vous existant.");
      const start=String(form.get("starts_on")||"");
      const end=String(form.get("ends_on")||"");
      if(end&&end<start) throw new Error("La date de fin doit suivre la date de début.");
      const {data,error}=await supabase.from("follow_up_plans").insert({
        doctor_id:doctorId,patient_id:appointment.patient_id,appointment_id:appointment.id,
        title:String(form.get("title")||""),instructions:String(form.get("instructions")||""),
        starts_on:start,ends_on:end||null,status:"draft"
      }).select("id").single();
      if(error) throw error;
      setDraftId(data.id);
      setMessage("Brouillon enregistré. Relisez-le avant publication.");
      event.currentTarget.reset();
    } catch(e) {setMessage(e instanceof Error?e.message:"Impossible d'enregistrer le suivi.");}
    finally {setBusy(false);}
  }
  async function publish() {
    if(!draftId)return;
    setBusy(true);
    try {
      const supabase=createClient();
      const {error}=await supabase.from("follow_up_plans").update({status:"published",approved_at:new Date().toISOString()}).eq("id",draftId);
      if(error)throw error;
      setMessage("Suivi publié dans l'espace du patient.");
      setDraftId(null);
    } catch(e) {setMessage(e instanceof Error?e.message:"Publication impossible.");}
    finally {setBusy(false);}
  }
  return <section className="panel" style={{marginTop:16}}>
    <h2>Créer un suivi post-consultation</h2>
    {appointments.length===0?<p style={{color:"var(--muted)"}}>Un rendez-vous doit exister avant de créer un suivi.</p>:<form onSubmit={submit}>
      <div className="input"><label>Rendez-vous / patient</label><select name="appointment" required defaultValue=""><option value="" disabled>Choisir un rendez-vous</option>{appointments.map(a=><option key={a.id} value={a.id}>Patient #{a.patient_id.slice(0,8)} · {new Date(a.starts_at).toLocaleString("fr-DZ")}</option>)}</select></div>
      <div className="input"><label>Titre du suivi</label><input name="title" required maxLength={120}/></div>
      <div className="input"><label>Consignes validées par le médecin</label><textarea name="instructions" required rows={4} maxLength={3000}/></div>
      <div className="two"><div className="input"><label>Début</label><input type="date" name="starts_on" required/></div><div className="input"><label>Fin (facultatif)</label><input type="date" name="ends_on"/></div></div>
      <button className="btn primary" type="submit" disabled={busy}>Enregistrer le brouillon</button>
    </form>}
    {draftId&&<button className="btn soft" style={{marginTop:10}} onClick={publish} disabled={busy}>Publier ce suivi au patient</button>}
    {message&&<div className="notice" role="status">{message}</div>}
  </section>;
}
