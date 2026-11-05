"use client";
import {useState} from "react";
import {useRouter} from "next/navigation";
import {createClient} from "@/lib/supabase/client";
export default function PatientCancelAction({table,id,status}:{table:"appointments"|"home_visit_requests";id:string;status:string}){
 const [busy,setBusy]=useState(false),[error,setError]=useState("");const router=useRouter();
 const canCancel=table==="appointments"?["requested","confirmed"].includes(status):status==="requested";
 if(!canCancel)return <span className="tag">{status}</span>;
 async function cancel(){if(!window.confirm("Confirmer l'annulation de cette demande ?"))return;setBusy(true);setError("");try{const supabase=createClient();const {error}=await supabase.from(table).update({status:"cancelled"}).eq("id",id);if(error)throw error;router.refresh();}catch(e){setError(e instanceof Error?e.message:"Annulation impossible.");}finally{setBusy(false);}}
 return <div><button className="btn quiet" type="button" disabled={busy} onClick={cancel}>{busy?"Annulation…":"Annuler"}</button>{error&&<small role="alert" style={{color:"#a33"}}>{error}</small>}</div>;
}