import type {CarePlanContext,AgentLocale,AgentResult} from "./follow-up-agent";
import {selectApprovedEvidence} from "./provider-adapter";
import {answerFromCarePlan} from "./follow-up-agent";
const injection=/ignore (all|any|previous|prior)|disregard (all|previous)|system prompt|developer message|reveal (the|other)|bypass (safety|policy)|override (the|all) rules|act as (a|an) (doctor|clinician)/i;
const stop=new Set(["the","and","for","with","what","when","where","how","does","can","could","should","would","from","your","this","that","have","has","are","is","was","were","les","des","une","un","pour","dans","avec","quoi","quand","comment","est","sont","mon","ma","mes","votre","vos","que","qui","sur","aux","du","de","la","le","en","et","ou","je","dois","peux","هل","ما","ماذا","كيف","متى","من","في","على","إلى","عن","هذا","هذه","هو","هي","مع"]);
function norm(s:string){return s.toLocaleLowerCase().normalize("NFKD").replace(/[\u064B-\u065F\u0670]/g,"").replace(/[\u0300-\u036f]/g,"").replace(/[^\p{L}\p{N}\s]/gu," ").split(/\s+/).filter(x=>x.length>1&&!stop.has(x))}
export async function retrievePatientAnswer(message:string,context:CarePlanContext,locale:AgentLocale):Promise<AgentResult>{
 const deterministic=answerFromCarePlan(message,context,locale);
 if(deterministic.outcome!=="human_handoff"||deterministic.intent!=="unknown")return deterministic;
 const query=new Set(norm(message));if(!query.size)return deterministic;
 const source=[context.title,...context.instructions.split(/\n+|(?<=[.!?؟؛])\s+/u),...context.events.flatMap(e=>[e.label,e.instruction||""])].map(x=>x.trim()).filter(x=>x.length>=12);
 const ranked=source.map((text,index)=>{const words=new Set(norm(text));const overlap=[...query].filter(word=>words.has(word)).length;return{text,index,overlap,score:overlap/Math.max(query.size,1)}}).filter(x=>x.overlap>0).sort((a,b)=>b.score-a.score||b.overlap-a.overlap||a.index-b.index).slice(0,8);
 const chunks=ranked.map(x=>x.text);if(!chunks.length||chunks.some(chunk=>injection.test(chunk)))return deterministic;
 try{const evidence=await selectApprovedEvidence(message,chunks,locale);if(!evidence.length)return deterministic;const heading=locale==="ar"?"مقاطع من برنامجك المعتمد:":locale==="en"?"Relevant excerpts from your approved plan:":"Extraits pertinents de votre programme validé :";return{intent:"plan_lookup",outcome:"answered_from_plan",answer:heading+"\n"+evidence.map(x=>"• "+x).join("\n"),handoff:false,safetyFlags:["plan_scoped_retrieval","model_selected_verbatim_evidence"]}}catch{return deterministic}
}
