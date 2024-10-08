##cor=bim_sum_stats[which(LDblocks2[[1]]==i),]; num=which(i==unique(LDblocks2[[1]]));nsnp=nrow(bim_sum_stats)
block_calculation2<-function(cor,num,train_file,nsnp,temp.file, plink){
  temp_file=paste0(temp.file,"_block_",num)
  write.table(cor$V2,file=temp_file,col.names=F,row.names=F,quote=F)
  cmd = paste0(plink, " --bfile ",train_file," --extract ",temp_file,   " --recodeA  --out ", temp_file,"_Geno.txt")
  system(cmd)

  Gtemp=try(as.data.frame(fread(paste0(temp_file,"_Geno.txt.raw"),header=T)),silent=T)
  if (file.exists(temp_file)) {file.remove(temp_file)}
  if (file.exists(paste0(temp_file,"_Geno.txt.nosex"))) {file.remove(paste0(temp_file,"_Geno.txt.nosex"))}
  if (file.exists(paste0(temp_file,"_Geno.txt.log"))) {file.remove(paste0(temp_file,"_Geno.txt.log"))}
  if (file.exists(paste0(temp_file,"_Geno.txt.raw"))) {file.remove(paste0(temp_file,"_Geno.txt.raw"))}

  if (class(Gtemp)=="try-error"){
    return(NULL)
    #GG=diag(nrow(cor));colnames(GG)=paste0(cor$V2,"_",cor$V5)
    #geno_info=as.data.frame(t(sapply(colnames(GG),   split_SNPandA1   ) )) ;colnames(geno_info)=c("SNP","A1")
    #geno_info$mean=NA; geno_info$maf=NA; geno_info$sd=NA
  }else{
    GG=cor(as.matrix(Gtemp[,7:ncol(Gtemp)]), use='p')
    geno_info=as.data.frame(t(sapply(colnames(Gtemp)[7:ncol(Gtemp)], split_SNPandA1   ) )) ;colnames(geno_info)=c("SNP","A1")
    geno_info$mean=colMeans(as.matrix(Gtemp[,7:ncol(Gtemp)]),na.rm=T); geno_info$maf=geno_info$mean/2; geno_info$sd=sqrt(2*geno_info$maf*(1-geno_info$maf))
  }

  list1=which(geno_info$sd==0)
  if (length(list1)>0){
    geno_info=geno_info[-list1,]
    GG=GG[-list1,-list1]
  }
  if (nrow(geno_info)==0){
    return(NULL)
  } else {
    gene_info3<-NULL
    geno_info$order=1:nrow(geno_info)
    for(i in 1:length(names(cor)[grepl('Beta', names(cor))])){
      beta_name<-names(cor)[grepl('Beta', names(cor))][i]
      geno_info2=merge(cor[,c("V2","V5",beta_name,"cor"), with=F],geno_info, by.x="V2",by.y="SNP",sort=F)
      names(geno_info2)[names(geno_info2) == beta_name]<-'Beta2'
      flag_nomatch=which(geno_info2$A1 != geno_info2$V5)
      if (length(flag_nomatch)>0){
        geno_info2$Beta2[flag_nomatch]=-geno_info2$Beta2[flag_nomatch]
        geno_info2$cor[flag_nomatch]=-geno_info2$cor[flag_nomatch]
      }
      GG2=as.matrix(GG[geno_info2$order,geno_info2$order])
      gy=geno_info2$cor
      betatemp=geno_info2$Beta2*geno_info2$sd
      u0=gy-GG2%*%betatemp
      beta.all=cbind(u0, betatemp)
      for (factor1 in c(1,10,100,1000)){
        k=1
        betatemp=beta.all[,2]
        u0=beta.all[,1]
        while (k<=15){
          ##betanew=c()
          learningrate=1/nsnp*factor1
          if (learningrate>1){learningrate=1}
          ##print(learningrate)
          for (j in 1:length(betatemp)){
            beta_old=betatemp[j]
            betatemp[j]=(learningrate*u0[j]+beta_old)/ 1
            u0=u0-GG2[,j]*(betatemp[j]-beta_old)
          }
          beta.all=cbind(beta.all,betatemp)
          k=k+1
        }
      }
      beta.all<-beta.all[, -1, drop = FALSE]
      colnames(beta.all)<-paste0(beta_name, '_TLPRS_', 1:ncol(beta.all))
      if(is.null(gene_info3)){
        gene_info3<-cbind(geno_info2, beta.all)
      } else {
        gene_info3<-cbind(gene_info3, beta.all)
      }
    }
    return(gene_info3)
  }
}##function end




##PRStr_calculation2(sum_stats_target, train_file, sum_stats, LDblocks, cluster=cluster,temp.file=paste0(tempfile,"_step1"))
##temp.file=paste0(tempfile,"_step1")
PRStr_calculation2<-function(sum_stats_target, train_file, sum_stats, LDblocks, temp.file, plink='plink-1.9'){
  possible.LDblocks <- c("EUR.hg19", "AFR.hg19", "ASN.hg19",
                         "EUR.hg38", "AFR.hg38", "ASN.hg38")
  if(!is.null(LDblocks)) {
    if(is.character(LDblocks) && length(LDblocks) == 1) {
      if(LDblocks %in% possible.LDblocks) {
        LDblocks <- data.table::fread(system.file(paste0("data/Berisa.",  LDblocks, ".bed"),  package="lassosum"), header=T)
      } else {
        stop(paste("I cannot recognize this LDblock. Specify one of",
                   paste(possible.LDblocks, collapse=", ")))
      }
    }
    if(is.factor(LDblocks)) LDblocks <- as.integer(LDblocks)
    if(is.vector(LDblocks)) stopifnot(length(LDblocks) == length(cor)) else
      if(is.data.frame(LDblocks) || is.data.table(LDblocks)) {
        LDblocks <- as.data.frame(LDblocks)
        stopifnot(ncol(LDblocks) == 3)
        stopifnot(all(LDblocks[,3] >= LDblocks[,2]))
        LDblocks[,1] <- as.character(sub("^chr", "", LDblocks[,1], ignore.case = T))
      }
  } else {
    stop(paste0("LDblocks must be specified. Specify one of ",
                paste(possible.LDblocks, collapse=", "),
                ". Alternatively, give an integer vector defining the blocks, ",
                "or a .bed file with three columns read as a data.frame."))
  }

  ref.bim <- fread(paste0(train_file, ".bim"))
  ref.bim$V1 <- as.character(sub("^chr", "", ref.bim$V1, ignore.case = T))
  ref.bim$order=1:nrow(ref.bim)
  bim_sum_stats=merge(ref.bim, sum_stats_target,by.x="V2",by.y="SNP",order=F)
  bim_sum_stats=bim_sum_stats[order(bim_sum_stats$order),]

  betas<-bim_sum_stats[, grepl('Beta', names(bim_sum_stats)), with=F, drop = FALSE]
  bim_sum_stats<-bim_sum_stats[, !grepl('Beta', names(bim_sum_stats)), with=F]

  flag2=which(bim_sum_stats$V6==bim_sum_stats$A1)
  if (length(flag2)>0){
    betas[flag2, ] = -betas[flag2, ]
    bim_sum_stats$cor[flag2] = -bim_sum_stats$cor[flag2]
  }

  bim_sum_stats=data.table(cbind(bim_sum_stats[,c("V2","V1","V4","V5","V6","order","cor"), with=F], betas))

  ref.extract <- rep(FALSE, nrow(ref.bim))
  ref.extract[bim_sum_stats$order] <- TRUE

  if(!is.null(LDblocks)) {
      LDblocks2 <- splitgenome2(CHR = ref.bim$V1[ ref.extract],
                              POS = ref.bim$V4[ ref.extract],
                              ref.CHR = LDblocks[,1],
                              ref.breaks = LDblocks[,3])
      # Assumes base 1 for the 3rd column of LDblocks (like normal bed files)
  }

  blocks<-unique(LDblocks2[[1]])
  batch_size<-100
  results.list <- list()
  for(batch_start in seq(1, length(blocks), by = batch_size)){
    batch_indices <- batch_start:min(batch_start + batch_size - 1, length(blocks))
    current_batch <- blocks[batch_indices]

    batch_results <- foreach(i = current_batch, .options.multicore = list(preschedule = FALSE)) %dopar% {
      block_calculation2(
        cor = bim_sum_stats[which(LDblocks2[[1]] == i), ],
        num = which(i == unique(LDblocks2[[1]])),
        train_file = train_file,
        nsnp = nrow(bim_sum_stats),
        temp.file,
        plink = plink
      )
    }
    results.list <- c(results.list, batch_results)
  }

  results.list<-do.call("rbind", results.list)

  return(results.list)
}







######################The function used summary statistics for training###############
##ped_file=ped.file;Covar_name="";Y_name=kword;Ytype="C"; train_file=train.bfile;test_file=test.bfile;sum_stats_file=beta.file;LDblocks="EUR.hg19"
##ped.file,"",kword, Ytype="C",train.bfile,test.bfile,beta.file,target_sumstats_file,LDblocks="EUR.hg19",tempfile
TL_PRS<-function(ped_file,Covar_name,Y_name, Ytype="C",train_file,test_file,sum_stats_file,target_sumstats_file, LDblocks="EUR.hg19",outfile,cluster=NULL){
	tempfile=outfile
	out1=PRStr_main_check(ped_file,Covar_name,Y_name, Ytype,train_file,test_file,sum_stats_file,LDblocks)
	if (out1!=0){stop(out1)}

	sum_stats=data.frame(fread(sum_stats_file))
	if (ncol(sum_stats)==3){
		if (sum(colnames(sum_stats) %in% c("V1","V2","V3"))==3){
			colnames(sum_stats)=c("SNP","A1","Beta")
		}
	}
	sum_stats=sum_stats[,c("SNP","A1","Beta")]
	sum_stats_file=paste0(tempfile,"_original_sum_stats.txt")
	write.table(sum_stats, file=sum_stats_file,col.names=F,row.names=F,quote=F)

	ped=data.frame(fread(ped_file,header=T))[,setdiff(c("FID","IID",Covar_name,Y_name),"")]

	##obj=calculate_betaPRS(train_file,sum_stats_file,ped,Covar_name,Y_name,paste0(tempfile,"_step0") ) ##need to remove sum_stats_file and plink command later.

	sum_stats_target=fread(target_sumstats_file)
	sum_stats_target=merge(sum_stats,sum_stats_target,by="SNP",sort=F)
	if (sum(sum_stats_target$p<=1E-320)>0){ sum_stats_target$p[sum_stats_target$p<=1E-320]=1E-320}

	sum_stats_target$cor=lassosum::p2cor(p = sum_stats_target$p, n = median(sum_stats_target$N,na.rm=T), sign=sum_stats_target$beta)
	flag=which(sum_stats_target$A1.x !=sum_stats_target$A1.y)
	if (length(flag)>0){sum_stats_target$cor[flag]=-sum_stats_target$cor[flag]}
	sum_stats_target=sum_stats_target[,c("SNP","A1.x","Beta","cor")];colnames(sum_stats_target)[2]="A1";
	gc()

	beta_list=as.data.frame(PRStr_calculation2(sum_stats_target, train_file, sum_stats, LDblocks, cluster=cluster,temp.file=paste0(tempfile,"_step1")))
	beta_list=as.data.frame(beta_list[,-c(5,9)])
	colnames(beta_list)[1:2]=c("SNP","A1")
	write.table(beta_list,file=paste0(tempfile,"_beta.candidates.txt"),row.names=F,quote=F,col.names=T)

	out1=PRStr_tuning(beta_list, ped,Covar_name, Y_name, Ytype,test_file)

  	if (file.exists(paste0(tempfile,"_original_sum_stats.txt"))) {file.remove(paste0(tempfile,"_original_sum_stats.txt"))}
  	if (file.exists(paste0(tempfile,"_step0.train.PRS.nosex"))) {file.remove(paste0(tempfile,"_step0.train.PRS.nosex"))}
  	if (file.exists(paste0(tempfile,"_step0.train.PRS.log"))) {file.remove(paste0(tempfile,"_step0.train.PRS.log"))}
  	if (file.exists(paste0(tempfile,"_step0.train.PRS.profile"))) {file.remove(paste0(tempfile,"_step0.train.PRS.profile"))}
	write.table(out1$best.beta,file=paste0(tempfile,"_best.beta.txt"),row.names=F,quote=F,col.names=T)
	write.table(out1$best.PRS,file=paste0(tempfile,"_best.PRS.txt"),row.names=F,quote=F,col.names=T)

	return(out1)
}
