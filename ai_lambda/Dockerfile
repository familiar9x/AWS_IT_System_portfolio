FROM public.ecr.aws/lambda/python:3.11

# Install Microsoft ODBC driver for SQL Server
RUN yum update -y && \
    yum install -y curl gnupg2 unixODBC unixODBC-devel

# Add Microsoft repository
RUN curl https://packages.microsoft.com/config/rhel/8/prod.repo > /etc/yum.repos.d/mssql-release.repo && \
    yum remove -y unixODBC-utf16 unixODBC-utf16-devel && \
    ACCEPT_EULA=Y yum install -y msodbcsql17 mssql-tools

# Set environment variables for ODBC
ENV PATH="$PATH:/opt/mssql-tools/bin"
ENV ODBCSYSINI="/lambda-entrypoint.d"

# Copy requirements and install Python packages
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Set the CMD to your handler
CMD ["lambda_function.lambda_handler"]
