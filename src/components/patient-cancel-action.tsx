"use client";
import {useState} from "react";import {useRouter} from "next/navigation";import {createClient} from "@/lib/supabase/client";import {tr} from "@/lib/i18n";
export default function PatientCancelAction({table,id,status,locale}:{table:"appointments"|"home_visit_requests";id:string;status:string;locale:string}){
 const [busy,setBusy]=useState(false),[error,setError]=useState("");const router=useRouter();
 const canCancel=table==="appointments"?["requested","confirmed"].includes(status):status==="requested";
 const label=(s:string)=>tr(locale,("status_"+s) as Parameters<typeof tr>[1]);
 if(!canCancel)return <span className="tag">{label(status)}</span>;
 async function cancel(){if(!window.confirm(tr(locale,"cancelConfirm")))return;setBusy(true);setError("");try{const supabase=createClient(),{error}=await supabase.from(table).update({status:"cancelled"}).eq("id",id);if(error)throw error;router.refresh();}catch{setError(tr(locale,"cancelFailed"));}finally{setBusy(false);}}
 return <div className="action-group"><button className="btn quiet" type="button" disabled={busy} onClick={cancel}>{busy?tr(locale,"cancelling"):tr(locale,"cancel")}</button>{error&&<small role="alert" className="form-error">{error}</small>}</div>;
}