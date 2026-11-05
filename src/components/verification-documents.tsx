"use client";
import {useState,type FormEvent} from "react";
import {createClient} from "@/lib/supabase/client";
type Doc={id:string;document_type:string;original_filename:string;status:string;review_note:string|null;created_at:string};
export default function VerificationDocuments({doctorId,userId,initialDocuments}:{doctorId:string;userId:string;initialDocuments:Doc[]}){
 const [docs,setDocs]=useState(initialDocuments),[busy,setBusy]=useState(false),[message,setMessage]=useState("");
 async function submit(e:FormEvent<HTMLFormElement>){
  e.preventDefault();setBusy(true);setMessage("");
  const form=e.currentTarget,values=new FormData(form),file=values.get("file");
  try{
   if(!(file instanceof File)||file.size===0)throw new Error("Sélectionnez un fichier.");
   if(file.size>10*1024*1024)throw new Error("Le fichier dépasse 10 Mo.");
   if(!["application/pdf","image/jpeg","image/png"].includes(file.type))throw new Error("Formats autorisés : PDF, JPG ou PNG.");
   const type=String(values.get("document_type"));
   const ext=file.name.split(".").pop()?.toLowerCase()||"bin";
   const path=userId+"/"+doctorId+"/"+crypto.randomUUID()+"."+ext;
   const supabase=createClient();
   const {error:uploadError}=await supabase.storage.from("doctor-verification").upload(path,file,{contentType:file.type,upsert:false});
   if(uploadError)throw uploadError;
   const {data,error:insertError}=await supabase.from("doctor_verification_documents").insert({doctor_id:doctorId,uploaded_by:userId,document_type:type,object_path:path,original_filename:file.name,mime_type:file.type,size_bytes:file.size}).select("id,document_type,original_filename,status,review_note,created_at").single();
   if(insertError){await supabase.storage.from("doctor-verification").remove([path]);throw insertError;}
   setDocs(old=>[...old, data as Doc]);form.reset();setMessage("Document transmis dans l'espace privé de vérification.");
  }catch(e){setMessage(e instanceof Error?e.message:"Échec du téléversement.");}
  finally{setBusy(false);}
 }
 return <section className="panel" style={{marginTop:16}}><h2>Documents professionnels</h2><p style={{color:"var(--muted)"}}>Téléversez une carte professionnelle, une autorisation ou un diplôme. Fichiers PDF/JPG/PNG, 10 Mo maximum. Documents privés, accessibles uniquement à vous et aux administrateurs habilités.</p>
 <form onSubmit={submit}>
  <div className="input"><label>Type de document</label><select name="document_type" required defaultValue="professional_card"><option value="professional_card">Carte professionnelle</option><option value="license">Autorisation / licence d'exercice</option><option value="diploma">Diplôme</option></select></div>
  <div className="input"><label>Fichier</label><input type="file" name="file" accept=".pdf,.jpg,.jpeg,.png,application/pdf,image/jpeg,image/png" required/></div>
  <button className="btn primary" type="submit" disabled={busy}>{busy?"Téléversement…":"Envoyer le document"}</button>
 </form>
 {message&&<div className="notice" role="status">{message}</div>}
 <div style={{marginTop:12,display:"grid",gap:8}}>{docs.map(d=><div className="row" key={d.id}><div><strong>{d.original_filename}</strong><small>{d.document_type} · {new Date(d.created_at).toLocaleDateString("fr-DZ")}</small>{d.review_note&&<small>{d.review_note}</small>}</div><span className="tag">{d.status}</span></div>)}</div>
 </section>;
}