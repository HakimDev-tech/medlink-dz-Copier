import "server-only";
import {Buffer} from "node:buffer";
export type DeliveryChannel="email"|"sms"|"whatsapp";
export type DeliveryPayload={to:string;locale:"fr"|"en"|"ar";category:string;appUrl:string;idempotencyKey:string};
export type DeliveryResult={providerMessageId:string|null};
export class DeliveryError extends Error{constructor(public code:string,public retryable:boolean){super(code)}}
const copy={
 fr:{subject:"Une notification MedLink DZ",appointment:"Vous avez une mise à jour concernant votre rendez-vous.",follow_up:"Un rappel de suivi est disponible dans votre espace sécurisé.",consultation:"Un document est disponible dans votre espace MedLink.",general:"Vous avez une nouvelle notification."},
 en:{subject:"A MedLink DZ notification",appointment:"There is an update about your appointment.",follow_up:"A follow-up reminder is available in your secure space.",consultation:"A document is available in your MedLink space.",general:"You have a new notification."},
 ar:{subject:"إشعار من MedLink DZ",appointment:"هناك تحديث بخصوص موعدك.",follow_up:"يوجد تذكير متابعة في فضائك الآمن.",consultation:"توجد وثيقة جديدة في فضاء MedLink.",general:"لديك إشعار جديد."}
};
function message(p:DeliveryPayload){const c=copy[p.locale]||copy.fr;return{subject:c.subject,body:c[p.category as keyof typeof c]||c.general};}
async function request(url:string,init:RequestInit){let response:Response;try{response=await fetch(url,{...init,cache:"no-store",signal:AbortSignal.timeout(15000)})}catch{throw new DeliveryError("provider_network_error",true)}if(!response.ok){const retryable=response.status===408||response.status===425||response.status===429||response.status>=500;throw new DeliveryError("provider_http_"+response.status,retryable)}return response.json().catch(()=>({})) as Promise<Record<string,unknown>>}
export function isChannelConfigured(channel:DeliveryChannel){if(channel==="email")return !!(process.env.RESEND_API_KEY&&process.env.MEDLINK_EMAIL_FROM);if(channel==="sms")return !!(process.env.TWILIO_ACCOUNT_SID&&process.env.TWILIO_AUTH_TOKEN&&process.env.TWILIO_SMS_FROM);return !!(process.env.WHATSAPP_ACCESS_TOKEN&&process.env.WHATSAPP_PHONE_NUMBER_ID&&process.env.WHATSAPP_TEMPLATE_NAME&&process.env.WHATSAPP_GRAPH_VERSION)}
export async function sendNotification(channel:DeliveryChannel,p:DeliveryPayload):Promise<DeliveryResult>{
 const {subject,body}=message(p);
 if(!isChannelConfigured(channel))throw new DeliveryError("provider_not_configured",false);
 if(channel==="email"){
  const result=await request("https://api.resend.com/emails",{method:"POST",headers:{"Authorization":"Bearer "+process.env.RESEND_API_KEY,"Content-Type":"application/json","Idempotency-Key":p.idempotencyKey},body:JSON.stringify({from:process.env.MEDLINK_EMAIL_FROM,to:[p.to],subject,text:body+"\n\n"+p.appUrl,html:"<p>"+body+"</p><p><a href=\""+p.appUrl+"\">Ouvrir MedLink DZ</a></p>"})});
  return{providerMessageId:typeof result.id==="string"?result.id:null};
 }
 if(channel==="sms"){
  const sid=process.env.TWILIO_ACCOUNT_SID!,token=process.env.TWILIO_AUTH_TOKEN!;
  const form=new URLSearchParams({To:p.to,From:process.env.TWILIO_SMS_FROM!,Body:body+" "+p.appUrl});
  const result=await request("https://api.twilio.com/2010-04-01/Accounts/"+encodeURIComponent(sid)+"/Messages.json",{method:"POST",headers:{"Authorization":"Basic "+Buffer.from(sid+":"+token).toString("base64"),"Content-Type":"application/x-www-form-urlencoded"},body:form.toString()});
  return{providerMessageId:typeof result.sid==="string"?result.sid:null};
 }
 const version=process.env.WHATSAPP_GRAPH_VERSION!;
 const language=p.locale==="ar"?"ar":p.locale==="en"?"en_US":"fr";
 const result=await request("https://graph.facebook.com/"+version+"/"+encodeURIComponent(process.env.WHATSAPP_PHONE_NUMBER_ID!)+"/messages",{method:"POST",headers:{"Authorization":"Bearer "+process.env.WHATSAPP_ACCESS_TOKEN,"Content-Type":"application/json"},body:JSON.stringify({messaging_product:"whatsapp",to:p.to,type:"template",template:{name:process.env.WHATSAPP_TEMPLATE_NAME,language:{code:language}}})});
 const messages=result.messages as Array<{id?:string}>|undefined;
 return{providerMessageId:messages?.[0]?.id||null};
}
