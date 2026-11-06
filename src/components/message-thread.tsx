"use client";
import {useEffect,useState,type FormEvent} from "react";
import {createClient} from "@/lib/supabase/client";
import {localeTag,tr} from "@/lib/i18n";
type Message={id:string;sender_id:string;body:string;created_at:string};
export default function MessageThread({conversationId,currentUserId,initialMessages,locale}:{conversationId:string;currentUserId:string;initialMessages:Message[];locale:string}){
 const [messages,setMessages]=useState(initialMessages),[body,setBody]=useState(""),[busy,setBusy]=useState(false),[error,setError]=useState("");
 useEffect(()=>{const supabase=createClient();const channel=supabase.channel("medlink-conversation-"+conversationId).on("postgres_changes",{event:"INSERT",schema:"public",table:"messages",filter:"conversation_id=eq."+conversationId},payload=>{const row=payload.new as Message;setMessages(old=>old.some(x=>x.id===row.id)?old:[...old,row]);}).subscribe();return()=>{void supabase.removeChannel(channel);};},[conversationId]);
 async function send(e:FormEvent<HTMLFormElement>){e.preventDefault();const value=body.trim();if(!value)return;setBusy(true);setError("");
  try{const supabase=createClient(),{data,error:authError}=await supabase.auth.getUser();if(authError||data.user?.id!==currentUserId)throw new Error(tr(locale,"sessionExpired"));
   const {data:row,error:insertError}=await supabase.from("messages").insert({conversation_id:conversationId,sender_id:currentUserId,body:value}).select("id,sender_id,body,created_at").single();if(insertError)throw insertError;if(row)setMessages(old=>old.some(x=>x.id===row.id)?old:[...old,row]);setBody("");
  }catch{setError(tr(locale,"messageFailed"));}finally{setBusy(false);}
 }
 return <section className="panel component-stack"><div className="message-list">{messages.length===0&&<p className="muted">{tr(locale,"noMessages")}</p>}
 {messages.map(m=><div key={m.id} className="message-bubble" data-own={m.sender_id===currentUserId}><p>{m.body}</p><small>{new Date(m.created_at).toLocaleString(localeTag(locale))}</small></div>)}</div>
 <form onSubmit={send} className="message-compose"><input aria-label={tr(locale,"messageLabel")} value={body} onChange={e=>setBody(e.target.value)} maxLength={4000} placeholder={tr(locale,"writeMessage")} required/><button className="btn primary" type="submit" disabled={busy||!body.trim()}>{busy?tr(locale,"messageSending"):tr(locale,"send")}</button></form>
 {error&&<p role="alert" className="form-error">{error}</p>}</section>;
}