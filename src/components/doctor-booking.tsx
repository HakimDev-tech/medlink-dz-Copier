"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function DoctorBooking({ doctorId, locale }: { doctorId: string; locale: string }) {
  const [open,setOpen]=useState(false);
  const [busy,setBusy]=useState(false);
  const [message,setMessage]=useState("");
  const router=useRouter();

  async function submit(event:FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setMessage("");
    try {
      const supabase=createClient();
      const {data,error}=await supabase.auth.getUser();
      if(error) throw error;
      if(!data.user) { router.push("/"+locale+"/login"); return; }
      const form=new FormData(event.currentTarget);
      const startsAt=new Date(String(form.get("starts_at")||""));
      if(Number.isNaN(startsAt.getTime()) || startsAt.getTime()<=Date.now()) throw new Error("Choisissez une date future.");
      const {error:insertError}=await supabase.from("appointments").insert({
        patient_id:data.user.id, doctor_id:doctorId, starts_at:startsAt.toISOString(), status:"requested"
      });
      if(insertError) throw insertError;
      setMessage("Demande envoyée. Le professionnel doit encore confirmer le rendez-vous.");
      setOpen(false);
    } catch(e) { setMessage(e instanceof Error?e.message:"Impossible d'envoyer la demande."); }
    finally { setBusy(false); }
  }

  const min=new Date(Date.now()-new Date().getTimezoneOffset()*60000).toISOString().slice(0,16);
  return <div style={{marginTop:14}}>
    <button className="btn primary" type="button" onClick={()=>setOpen(v=>!v)}>{open?"Fermer":"Demander un rendez-vous"}</button>
    {open&&<form onSubmit={submit} className="input" style={{marginTop:12}}>
      <label>Date et heure souhaitées</label>
      <input name="starts_at" type="datetime-local" min={min} required/>
      <button className="btn primary" disabled={busy} type="submit">{busy?"Envoi…":"Envoyer la demande"}</button>
    </form>}
    {message&&<div className="notice" role="status">{message}</div>}
  </div>;
}
