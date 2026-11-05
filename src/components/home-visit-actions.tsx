"use client";
import {useState} from "react";
import {useRouter} from "next/navigation";
import {createClient} from "@/lib/supabase/client";
export default function HomeVisitActions({id,status}:{id:string;status:string}){
 const [busy,setBusy]=useState(false),[error,setError]=useState("");const router=useRouter();
 async function update(next:"accepted"|"rejected"|"completed"){setBusy(true);setError("");try{const supabase=createClient();const {error}=await supabase.from("home_visit_requests").update({status:next}).eq("id",id);if(error)throw error;router.refresh();}catch(e){setError(e instanceof Error?e.message:"Mise à jour impossible.");}finally{setBusy(false);}}
 return <div style={{display:"flex",gap:6,flexWrap:"wrap"}}>{status==="requested"&&<><button className="btn soft" disabled={busy} onClick={()=>update("accepted")}>Accepter</button><button className="btn quiet" disabled={busy} onClick={()=>update("rejected")}>Refuser</button></>}{status==="accepted"&&<button className="btn soft" disabled={busy} onClick={()=>update("completed")}>Terminer</button>}{error&&<small role="alert" style={{color:"#a33"}}>{error}</small>}</div>;
}