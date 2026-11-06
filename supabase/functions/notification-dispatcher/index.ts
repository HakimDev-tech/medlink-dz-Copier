import {createClient} from "https://esm.sh/@supabase/supabase-js@2";
const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type"};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,"Content-Type":"application/json"}});
const messages={
 fr:{title:"Rappel de suivi",body:(label:string)=>"Rappel prévu dans votre programme de suivi : "+label},
 en:{title:"Follow-up reminder",body:(label:string)=>"Reminder from your follow-up plan: "+label},
 ar:{title:"تذكير بالمتابعة",body:(label:string)=>"تذكير من برنامج المتابعة: "+label}
};
Deno.serve(async req=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
 if(req.method!=="POST")return json({error:"method_not_allowed"},405);
 const secret=Deno.env.get("DISPATCHER_SECRET"),provided=req.headers.get("x-dispatcher-secret");
 if(!secret||provided!==secret)return json({error:"unauthorized"},401);
 const url=Deno.env.get("SUPABASE_URL"),key=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
 if(!url||!key)return json({error:"server_configuration_missing"},500);
 const db=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data:jobs,error:claimError}=await db.rpc("claim_medlink_notification_jobs",{batch_size:50});
 if(claimError)return json({error:"claim_failed"},500);
 let sent=0,failed=0;
 for(const job of jobs??[]){
  try{
   const [{data:event,error:eventError},{data:profile,error:profileError}]=await Promise.all([
    db.from("follow_up_events").select("label").eq("id",job.event_id).single(),
    db.from("profiles").select("preferred_language").eq("id",job.user_id).single()
   ]);
   if(eventError||profileError||!event)throw new Error("reminder_context_unavailable");
   const lang=profile?.preferred_language==="ar"?"ar":profile?.preferred_language==="en"?"en":"fr";
   const copy=messages[lang];
   const {error:insertError}=await db.from("notifications").upsert({user_id:job.user_id,title:copy.title,body:copy.body(event.label),category:"follow_up",scheduled_for:job.due_at,sent_at:new Date().toISOString(),source_job_id:job.id},{onConflict:"source_job_id",ignoreDuplicates:true});
   if(insertError)throw insertError;
   await db.from("notification_schedules").update({status:"sent",last_error:null,updated_at:new Date().toISOString()}).eq("id",job.id);
   await db.from("notification_logs").insert({job_id:job.id,attempt:job.attempts,outcome:"sent"});
   sent++;
  }catch(error){
   const detail=error instanceof Error?error.message:"dispatch_failed";
   const terminal=job.attempts>=job.max_attempts;
   const delay=Math.min(3600,30*Math.pow(2,Math.max(0,job.attempts-1)));
   await db.from("notification_schedules").update({status:"failed",last_error:detail,next_attempt_at:new Date(Date.now()+delay*1000).toISOString(),updated_at:new Date().toISOString()}).eq("id",job.id);
   await db.from("notification_logs").insert({job_id:job.id,attempt:job.attempts,outcome:terminal?"failed":"retry",detail});
   failed++;
  }
 }
 return json({claimed:(jobs??[]).length,sent,failed});
});
