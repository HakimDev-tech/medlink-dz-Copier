"use client";
import {useState} from "react";
import {useRouter} from "next/navigation";
import {createClient} from "@/lib/supabase/client";
import {tr} from "@/lib/i18n";
export default function CareEscalationActions({id,status,locale}:{id:string;status:"open"|"in_review"|"resolved";locale:string}){
 const [busy,setBusy]=useState(false),[error,setError]=useState("");const router=useRouter();
 async function update(next:"in_review"|"resolved"){setBusy(true);setError("");try{const supabase=createClient();const {error}=await supabase.from("care_agent_escalations").update({status:next,...(next==="resolved"?{resolved_at:new Date().toISOString()}:{})}).eq("id",id);if(error)throw error;router.refresh();}catch{setError(tr(locale,"escalationUpdateFailed"));}finally{setBusy(false);}}
 return <div className="action-group">{status==="open"&&<button className="btn soft" disabled={busy} onClick={()=>update("in_review")}>{tr(locale,"markReview")}</button>}{status!=="resolved"&&<button className="btn primary" disabled={busy} onClick={()=>update("resolved")}>{tr(locale,"resolveEscalation")}</button>}{error&&<small role="alert">{error}</small>}</div>;
}