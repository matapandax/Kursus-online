#!/bin/bash
# Upgrade learner ke mode 'verified' (untuk klaim sertifikat setelah bayar).
# Pemakaian: ./upgrade_to_verified.sh <username|email> <course_id>
# Contoh   : ./upgrade_to_verified.sh budi course-v1:LEF+2024+2026
set -e
U="$1"; C="$2"
if [ -z "$U" ] || [ -z "$C" ]; then
  echo "Usage: $0 <username|email> <course_id>"; exit 1
fi
cd /edx/app/edxapp/edx-platform
sudo -u edxapp env LMS_CFG=/edx/etc/lms.yml UPG_USER="$U" UPG_COURSE="$C" \
  /edx/app/edxapp/venvs/edxapp/bin/python manage.py lms shell --settings=production 2>/dev/null <<'PYEOF'
import os
from django.db.models import Q
from django.contrib.auth import get_user_model
from opaque_keys.edx.keys import CourseKey
from common.djangoapps.student.models import CourseEnrollment, CourseMode
ident=os.environ['UPG_USER']; cid=os.environ['UPG_COURSE']
U=get_user_model()
ck=CourseKey.from_string(cid)
user=U.objects.filter(Q(username=ident)|Q(email=ident)).first()
if not user:
    print("ERROR: user tidak ditemukan:", ident); raise SystemExit(1)
modes=CourseMode.modes_for_course_dict(ck)
if 'verified' not in modes:
    print("ERROR: course belum punya mode 'verified':", cid); raise SystemExit(1)
enr=CourseEnrollment.objects.filter(user=user, course_id=ck).first()
if not enr:
    print("INFO: belum enroll -> mendaftarkan langsung sebagai verified")
    CourseEnrollment.enroll(user, ck, mode='verified')
else:
    enr.update_enrollment(mode='verified', is_active=True)
print("OK: %s -> VERIFIED @ %s" % (user.username, cid))
# Picu pembuatan sertifikat (terbit jika nilai sudah lulus)
try:
    from lms.djangoapps.certificates.generation_handler import generate_certificate_task
    print("Trigger sertifikat:", generate_certificate_task(user, ck))
except Exception as e:
    print("Catatan sertifikat:", e)
from lms.djangoapps.certificates.models import GeneratedCertificate
gc=GeneratedCertificate.objects.filter(user=user, course_id=ck).first()
print("Status sertifikat:", (gc.status if gc else "belum ada (menunggu nilai lulus)"))
PYEOF
