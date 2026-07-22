-- Migration 0007: verification documents uploaded to private storage.
-- doc_url stays for legacy/external links; doc_key holds the private storage
-- object key, which is only ever resolved to a short-lived signed URL for
-- reviewers. Existing rows keep working unchanged.
ALTER TABLE verifications ADD COLUMN IF NOT EXISTS doc_key text;

-- doc_url was NOT NULL when a pasted link was the only option; uploads now
-- supply doc_key instead, so allow one of the two to be absent.
ALTER TABLE verifications ALTER COLUMN doc_url DROP NOT NULL;

ALTER TABLE verifications DROP CONSTRAINT IF EXISTS verifications_doc_present;
ALTER TABLE verifications ADD CONSTRAINT verifications_doc_present
  CHECK (doc_url IS NOT NULL OR doc_key IS NOT NULL);
