FROM python:3

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY ./src ./src/

ENV PYTHONPATH=/app
CMD python ./src/generate_starting_positions.py --maps $MAPS --adj_mat_source ./maps/map-sources.json
# CMD ls maps/
