"use client";
import { useEffect, useState, type FormEvent } from "react";
import { createClient } from "@/lib/supabase/client";
type Message={id:string;sender_id:string;body:string;created_at:string};
export default function MessageThread({conversationId,currentUserId,initialMessages}:{conversationId:string;currentUserId:string;initialMessages:Message[]}) {
 const [messages,setMessages]=useState(initialMessages),[body,setBody]=useState(""),[busy,setBusy]=useState(false),[error,setError]=useState("");
 useEffect(()=>{
  const supabase=createClient();
  const channel=supabase.channel("medlink-conversation-"+conversationId).on("postgres_changes",{event:"INSERT",schema:"public",table:"messages",filter:"conversation_id=eq."+conversationId},payload=>{
   const row=payload.new as Message;setMessages(old=>old.some(x=>x.id===row.id)?old:[...old,row]);
  }).subscribe();
  return()=>{void supabase.removeChannel(channel);};
 },[conversationId]);
 async function send(e:FormEvent<HTMLFormElement>){
  e.preventDefault();const value=body.trim();if(!value)return;setBusy(true);setError("");
  try{const supabase=createClient();const {data,error:authError}=await supabase.auth.getUser();if(authError)throw authError;if(data.user?.id!==currentUserId)throw new Error("Session expirée. Reconnectez-vous.");
   const {data:row,error:insertError}=await supabase.from("messages").insert({conversation_id:conversationId,sender_id:currentUserId,body:value}).select("id,sender_id,body,created_at").single();
   if(insertError)throw insertError;if(row)setMessages(old=>old.some(x=>x.id===row.id)?old:[...old,row]);setBody("");
  }catch(e){setError(e instanceof Error?e.message:"Envoi impossible.");}finally{setBusy(false);}
 }
 return <section className="panel" style={{marginTop:14}}>
  <div style={{display:"grid",gap:10,maxHeight:280,overflowY:"auto",padding:"4px 0"}}>
   {messages.length===0&&<p style={{color:"var(--muted)"}}>Aucun message. Vous pouvez commencer la conversation.</p>}
   {messages.map(m=><div key={m.id} style={{justifySelf:m.sender_id===currentUserId?"end":"start",maxWidth:"88%",background:m.sender_id===currentUserId?"var(--mint)":"var(--surface)",border:"1px solid var(--line)",borderRadius:12,padding:10}}>
    <p style={{whiteSpace:"pre-wrap",margin:0}}>{m.body}</p><small>{new Date(m.created_at).toLocaleString("fr-DZ")}</small>
   </div>)}
  </div>
  <form onSubmit={send} style={{display:"flex",gap:8,marginTop:12}}>
   <input aria-label="Votre message" value={body} onChange={e=>setBody(e.target.value)} maxLength={4000} placeholder="Écrire un message…" required style={{flex:1,minWidth:0}}/>
   <button className="btn primary" type="submit" disabled={busy||!body.trim()}>{busy?"Envoi…":"Envoyer"}</button>
  </form>{error&&<p role="alert" style={{color:"#a33"}}>{error}</p>}
 </section>;
}