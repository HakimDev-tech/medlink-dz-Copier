"use client";
import {useState} from "react";import {useRouter} from "next/navigation";import {createClient} from "@/lib/supabase/client";import {tr} from "@/lib/i18n";
type Status="pending"|"in_review"|"verified"|"rejected"|"suspended";
export default function VerificationAction({id,status,locale}:{id:string;status:Status;locale:string}){
 const [busy,setBusy]=useState(false),[error,setError]=useState("");const router=useRouter();
 async function update(next:Status){setBusy(true);setError("");try{const supabase=createClient(),{error}=await supabase.from("doctors").update({verification_status:next}).eq("id",id);if(error)throw error;router.refresh();}catch{setError(tr(locale,"decisionFailed"));}finally{setBusy(false);}}
 const labels:Record<Status,string>={pending:tr(locale,"status_pending"),in_review:tr(locale,"status_in_review"),verified:tr(locale,"status_verified"),rejected:tr(locale,"status_rejected"),suspended:tr(locale,"status_suspended")};
 return <div className="component-stack" style={{minWidth:160}}><label className="sr-only" htmlFor={"verification-"+id}>{tr(locale,"decisionFailed")}</label><select id={"verification-"+id} value={status} disabled={busy} onChange={e=>update(e.target.value as Status)}>{(Object.keys(labels) as Status[]).map(s=><option key={s} value={s}>{labels[s]}</option>)}</select>{error&&<small role="alert" className="form-error">{error}</small>}</div>;
}