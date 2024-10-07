FROM rust:1.81-bookworm

# install circom
RUN apt -y update && apt -y install git 
RUN git clone https://github.com/iden3/circom.git && cd circom/ && cargo build --release && cargo install --path circom 
RUN rm -rf circom/

# install snarkJS
ENV NODE_VERSION=20.18.0
RUN apt install -y curl
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
ENV NVM_DIR=/root/.nvm
RUN . "$NVM_DIR/nvm.sh" && nvm install ${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm use v${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm alias default v${NODE_VERSION}
ENV PATH="/root/.nvm/versions/node/v${NODE_VERSION}/bin/:${PATH}"
RUN npm install -g snarkjs

# install Noir
RUN curl -L https://raw.githubusercontent.com/noir-lang/noirup/main/install | bash
RUN /root/.nargo/bin/noirup

# install co-circom
RUN git clone https://github.com/TaceoLabs/collaborative-circom.git --branch co-noir-v0.2.0 && cargo install --path collaborative-circom/co-circom/co-circom/ && cargo install --path collaborative-circom/co-noir/co-noir/
RUN rm -rf collaborative-circom

# download files for Demo
WORKDIR /app
RUN git clone https://github.com/TaceoLabs/zksummit12_workshop.git && mv zksummit12_workshop/* . && rm Dockerfile && rm zksummit12_workshop -r

# install some quality of live (no, seriously they are great)
RUN cargo install bat
RUN cargo install just


