"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
type Status="pending"|"in_review"|"verified"|"rejected"|"suspended";
export default function VerificationAction({id,status}:{id:string;status:Status}) {
 const [busy,setBusy]=useState(false),[error,setError]=useState("");
 const router=useRouter();
 async function update(next:Status) {
  setBusy(true);setError("");
  try { const supabase=createClient(); const {error:writeError}=await supabase.from("doctors").update({verification_status:next}).eq("id",id); if(writeError)throw writeError; router.refresh(); }
  catch(e) {setError(e instanceof Error?e.message:"La mise à jour a échoué.");}
  finally {setBusy(false);}
 }
 return <div style={{display:"grid",gap:6,minWidth:150}}>
  <select aria-label="Décision de vérification" value={status} disabled={busy} onChange={e=>update(e.target.value as Status)}>
   <option value="pending">En attente</option><option value="in_review">En examen</option><option value="verified">Vérifié</option><option value="rejected">Rejeté</option><option value="suspended">Suspendu</option>
  </select>{error&&<small role="alert" style={{color:"#a33"}}>{error}</small>}
 </div>;
}