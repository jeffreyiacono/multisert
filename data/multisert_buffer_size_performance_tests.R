install.packages("lattice")
require(lattice)

runs = read.csv("./multisert_buffer_size_performance_tests.csv", header = TRUE, sep = ",")

# buffer sizes 0 - 10
xyplot(runs$performance_test_1[1:11] +
       runs$performance_test_2[1:11] +
       runs$performance_test_3[1:11] ~ runs$buffer_size[1:11]
     , type=c('p', 'g', 'b')
     , pch=20
     , lty="dotted"
     , xlab="Buffer Size"
     , ylab="Time to INSERT 100,000 records in seconds"
     , main="Multisert Performance Test"
     , scales=list(x=list(tick.number=10)
                 , y=list(limits=c(0,60), tick.number=20)))

# buffer sizes 0 - 100
xyplot(runs$performance_test_1[1:20] +
       runs$performance_test_2[1:20] +
       runs$performance_test_3[1:20] ~ runs$buffer_size[1:20]
     , type=c('p', 'g', 'b')
     , pch=20
     , lty="dotted"
     , xlab="Buffer Size"
     , ylab="Time to INSERT 100,000 records in seconds"
     , main="Multisert Performance Test"
     , scales=list(x=list(tick.number=10)
                 , y=list(limits=c(0,60), tick.number=20)))

# buffer sizes 0 - 1,000
xyplot(runs$performance_test_1[1:110] +
       runs$performance_test_2[1:110] +
       runs$performance_test_3[1:110] ~ runs$buffer_size[1:110]
     , type=c('p', 'g', 'b')
     , pch=20
     , lty="dotted"
     , main="Multisert Performance Test"
     , xlab="Buffer Size"
     , ylab="Time to INSERT 100,000 records in seconds"
     , scales=list(x=list(tick.number=10)
                 , y=list(limits=c(0,60), tick.number=20)))

# all buffer sizes in performance test
xyplot(runs$performance_test_1 +
       runs$performance_test_2 +
       runs$performance_test_3 ~ runs$buffer_size
     , type=c('p', 'g', 'b')
     , pch=20
     , lty="dotted"
     , main="Multisert Performance Test"
     , xlab="Buffer Size"
     , ylab="Time to INSERT 100,000 records in seconds"
     , scales=list(x=list(tick.number=10)
                 , y=list(limits=c(0,60), tick.number=20)))
