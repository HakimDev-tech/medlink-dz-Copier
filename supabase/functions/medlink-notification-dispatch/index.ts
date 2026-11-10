import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {createClient} from "npm:@supabase/supabase-js@2";
import {channelAvailability,deliver,type DeliveryChannel,type DeliveryPayload,DeliveryError} from "./notification-providers.ts";
const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization,content-type"};
const json=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers:{...cors,"Content-Type":"application/json"}});
const retrySeconds=[60,300,900,3600,21600];
type Job={id:string;notification_id:string;user_id:string;channel:DeliveryChannel;attempt:number;idempotency_key:string};
Deno.serve(async(req:Request)=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
 if(req.method==="GET")return json({availability:channelAvailability()});
 if(req.method!=="POST")return json({error:"method_not_allowed"},405);
 const supplied=req.headers.get("authorization")?.replace(/^Bearer\s+/i,"")||"";
 const url=Deno.env.get("SUPABASE_URL"),serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
 if(!url||!serviceKey)return json({error:"worker_not_configured"},503);
 const db=createClient(url,serviceKey,{auth:{persistSession:false,autoRefreshToken:false}});
 const{data:valid,error:secretError}=await db.rpc("validate_medlink_notification_dispatch_secret",{p_secret:supplied});
 if(secretError||valid!==true)return json({error:"unauthorized"},401);
 const{data:jobs,error:claimError}=await db.rpc("claim_notification_delivery_jobs",{p_batch_size:25});
 if(claimError)return json({error:"queue_unavailable"},503);
 let sent=0,failed=0,retried=0;
 for(const job of (jobs||[]) as Job[]){
  try{
   const[{data:notice,error:noticeError},{data:profile,error:profileError},{data:prefs,error:prefsError},{data:authResult,error:authError}]=await Promise.all([db.from("notifications").select("category").eq("id",job.notification_id).maybeSingle(),db.from("profiles").select("phone,preferred_language").eq("id",job.user_id).maybeSingle(),db.from("notification_preferences").select("email_enabled,sms_enabled,whatsapp_enabled,email_consent_at,sms_consent_at,whatsapp_consent_at").eq("user_id",job.user_id).maybeSingle(),db.auth.admin.getUserById(job.user_id)]);
   if(noticeError||profileError||authError||!notice||!profile||!authResult.user)throw new DeliveryError("recipient_lookup_failed",true);
   const user=authResult.user,locale=profile.preferred_language==="ar"||profile.preferred_language==="en"?profile.preferred_language:"fr";let destination="";
   if(job.channel==="email"){if(!user.email_confirmed_at||!user.email)throw new DeliveryError("recipient_not_verified",false);destination=user.email}
   else{const stored=profile.phone?.replace(/[\s().-]/g,"")||"",phone=user.phone?.replace(/[\s().-]/g,"")||"";if(!user.phone_confirmed_at||!phone||stored!==phone)throw new DeliveryError("recipient_not_verified",false);if(!/^\+[1-9]\d{7,14}$/.test(phone))throw new DeliveryError("phone_invalid",false);destination=phone}
   const payload:DeliveryPayload={to:destination,locale,category:notice.category||"general",appUrl:(Deno.env.get("MEDLINK_APP_URL")||"https://medlink-dz-three.vercel.app")+"/"+locale+"/patient",idempotencyKey:job.idempotency_key};
   const result=await deliver(job.channel,payload),now=new Date().toISOString();
   const{error:updateError}=await db.from("notification_delivery_jobs").update({status:"sent",sent_at:now,provider_message_id:result.providerMessageId,last_error:null,locked_at:null,updated_at:now}).eq("id",job.id).eq("status","processing");
   if(updateError)throw new DeliveryError("delivery_state_update_failed",true);
   await db.from("notification_delivery_logs").insert({job_id:job.id,attempt:job.attempt,outcome:"sent",provider_message_id:result.providerMessageId});sent++;
  }catch(error){const code=error instanceof DeliveryError?error.code:"delivery_failed",retryable=error instanceof DeliveryError?error.retryable:true,terminal=!retryable||job.attempt>=5;const next=new Date(Date.now()+(retrySeconds[Math.min(job.attempt-1,4)]||21600)*1000).toISOString();await db.from("notification_delivery_jobs").update({status:terminal?"failed":"pending",next_attempt_at:next,locked_at:null,last_error:code.slice(0,100),updated_at:new Date().toISOString()}).eq("id",job.id);await db.from("notification_delivery_logs").insert({job_id:job.id,attempt:job.attempt,outcome:terminal?"failed":"retry",error_code:code.slice(0,100)});if(terminal)failed++;else retried++}
 }
 return json({ok:true,processed:(jobs||[]).length,sent,failed,retryScheduled:retried});
});
