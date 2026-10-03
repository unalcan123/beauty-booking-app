-- Run once after admin_services.sql. Renames the services to Dutch,
-- including the service name stored on existing appointments.
update public.appointments set service = case service
  when 'Manikür & jel oje' then 'Manicure & gellak'
  when 'Saç kesimi & şekillendirme' then 'Knippen & stylen'
  when 'Kaş şekillendirme' then 'Wenkbrauwen modelleren'
  else service end;
update public.services set name = case id
  when 'manicure' then 'Manicure & gellak'
  when 'haircut' then 'Knippen & stylen'
  when 'brows' then 'Wenkbrauwen modelleren'
  else name end;
