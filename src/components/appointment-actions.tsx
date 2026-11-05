"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
export default function AppointmentActions({id,status}:{id:string;status:string}) {
 const [busy,setBusy]=useState(false);const [error,setError]=useState("");const router=useRouter();
 async function change(next:"confirmed"|"rejected"|"completed") {
  setBusy(true);setError("");
  try {const supabase=createClient();const {error:writeError}=await supabase.from("appointments").update({status:next}).eq("id",id);if(writeError)throw writeError;router.refresh();}
  catch(e){setError(e instanceof Error?e.message:"Mise à jour impossible.");}
  finally{setBusy(false);}
 }
 if(status==="completed"||status==="cancelled"||status==="rejected")return <span className="tag">{status}</span>;
 return <div style={{display:"flex",gap:6,flexWrap:"wrap",justifyContent:"end"}}>
  {status==="requested"&&<><button className="btn soft" type="button" disabled={busy} onClick={()=>change("confirmed")}>Confirmer</button><button className="btn quiet" type="button" disabled={busy} onClick={()=>change("rejected")}>Refuser</button></>}
  {status==="confirmed"&&<button className="btn soft" type="button" disabled={busy} onClick={()=>change("completed")}>Terminer</button>}
  {error&&<small role="alert" style={{color:"#a33"}}>{error}</small>}
 </div>;
}
