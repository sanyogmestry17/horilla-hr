FROM python:3.10-slim-bullseye AS builder

ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends libcairo2-dev gcc && rm -rf /var/lib/apt/lists/*

WORKDIR /app/

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.10-slim-bullseye AS runtime

ENV PYTHONUNBUFFERED=1

WORKDIR /app/

# wkhtmltopdf is a hard runtime dependency: payroll/views and base/methods shell
# out to it through pdfkit to render payslips. libcairo2 is the runtime half of
# the builder's libcairo2-dev, and the fonts keep generated PDFs from rendering
# every glyph as a box.
RUN apt-get update && apt-get install -y --no-install-recommends \
        wkhtmltopdf \
        libcairo2 \
        fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /install /usr/local

COPY . .

RUN chmod +x /app/entrypoint.sh /app/render-entrypoint.sh

# Baked into the image so it doesn't repeat on every cold start. collectstatic
# doesn't touch the database, so the settings defaults suffice at build time.
RUN python3 manage.py collectstatic --noinput

EXPOSE 8000

CMD ["/app/render-entrypoint.sh"]
