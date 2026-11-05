"use client";
import {useEffect,useState} from "react";
import {createClient} from "@/lib/supabase/client";
type Doc={id:string;object_path:string;original_filename:string;document_type:string;status:string;review_note:string|null;created_at:string};
export default function AdminVerificationDocuments({doctorId}:{doctorId:string}){
 const [docs,setDocs]=useState<Doc[]>([]),[error,setError]=useState("");
 useEffect(()=>{let active=true;const supabase=createClient();supabase.from("doctor_verification_documents").select("id,object_path,original_filename,document_type,status,review_note,created_at").eq("doctor_id",doctorId).order("created_at",{ascending:false}).then(({data,error})=>{if(!active)return;if(error)setError(error.message);else setDocs(data??[]);});return()=>{active=false;};},[doctorId]);
 async function open(path:string){const supabase=createClient();const {data,error}=await supabase.storage.from("doctor-verification").createSignedUrl(path,60);if(error){setError(error.message);return;}window.open(data.signedUrl,"_blank","noopener,noreferrer");}
 return <div style={{marginTop:8,display:"grid",gap:6}}>{docs.length===0?<small>Aucun justificatif téléversé.</small>:docs.map(d=><button key={d.id} className="btn quiet" type="button" onClick={()=>open(d.object_path)}>{d.document_type} · {d.original_filename} · {d.status}</button>)}{error&&<small role="alert" style={{color:"#a33"}}>{error}</small>}</div>;
}